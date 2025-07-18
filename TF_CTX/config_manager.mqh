//+------------------------------------------------------------------+
//|                                           config_manager.mqh     |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include "../utils/JAson.mqh"
#include "../utils/conversion.mqh"
#include "tf_ctx.mqh"
#include "config_types.mqh"

//+------------------------------------------------------------------+
//| Classe para gerenciar configurações e contextos                 |
//+------------------------------------------------------------------+
class CConfigManager
{
private:
    CJAVal m_config;
    string m_symbols[];
    TF_CTX *m_contexts[];
    string m_context_keys[];
    bool m_initialized;

    // Métodos privados
    bool LoadConfig(string json_content);
    bool LoadConfigFromFile(string file_path);
    bool CreateContexts();
    string TimeframeToString(ENUM_TIMEFRAMES tf);
    ENUM_TIMEFRAMES StringToTimeframe(string tf_str);
    ENUM_MA_METHOD StringToMAMethod(string method_str);
    ENUM_STO_PRICE StringToPriceField(string field_str);
    ENUM_APPLIED_PRICE StringToAppliedPrice(string price_str);
    ENUM_VWAP_CALC_MODE StringToVWAPCalcMode(string mode_str);
    ENUM_VWAP_PRICE_TYPE StringToVWAPPriceType(string type_str);
    ENUM_LINE_STYLE StringToLineStyle(string style_str);
    color StringToColor(string color_str);
    int OpenConfigFile(string file_path);
    void FillIndicatorBase(CIndicatorConfig &cfg, CJAVal *node, string type);
    void FillPriceActionBase(CPriceActionConfig &cfg, CJAVal *node, string type);
    CIndicatorConfig *CreateIndicatorConfig(CJAVal *ind);
    CPriceActionConfig *CreatePriceActionConfig(CJAVal *pa, ENUM_TIMEFRAMES tf);
    STimeframeConfig ParseTimeframeConfig(CJAVal *tf_config, ENUM_TIMEFRAMES tf);
    string CreateContextKey(string symbol, ENUM_TIMEFRAMES tf);
    bool TestJSONParsing();
    
public:
    // Construtor e Destrutor
    CConfigManager();
    ~CConfigManager();

    // Inicialização
    bool InitFromFile(string file_path);

    // Métodos públicos
    TF_CTX *GetContext(string symbol, ENUM_TIMEFRAMES timeframe);
    bool IsContextEnabled(string symbol, ENUM_TIMEFRAMES timeframe);
    void GetConfiguredSymbols(string &symbols[]);
    int GetSymbolContexts(string symbol, TF_CTX *&contexts[], ENUM_TIMEFRAMES &timeframes[]);
    void Cleanup();
    bool IsInitialized() const { return m_initialized; }
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CConfigManager::CConfigManager()
{
    m_initialized = false;
    ArrayResize(m_symbols, 0);
    ArrayResize(m_contexts, 0);
    ArrayResize(m_context_keys, 0);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CConfigManager::~CConfigManager()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| Inicialização do gerenciador com arquivo                        |
//+------------------------------------------------------------------+
bool CConfigManager::InitFromFile(string file_path)
{
    Print("Tentando carregar arquivo: ", file_path);
    
    if (!LoadConfigFromFile(file_path))
    {
        Print("ERRO: Falha ao carregar configuração do arquivo: ", file_path);
        return false;
    }

    if (!CreateContexts())
    {
        Print("ERRO: Falha ao criar contextos");
        return false;
    }

    m_initialized = true;
    Print("ConfigManager inicializado com sucesso do arquivo: ", file_path);
    Print("Símbolos carregados: ", ArraySize(m_symbols));
    return true;
}

//+------------------------------------------------------------------+
//| Carregar configuração do JSON                                   |
//+------------------------------------------------------------------+
bool CConfigManager::LoadConfig(string json_content)
{
    Print("Tentando fazer parse do JSON...");
    Print("Tamanho do JSON: ", StringLen(json_content), " caracteres");
    
    // Limpar configuração anterior
    m_config.Clear();
    
    // Testar parsing básico primeiro
    if(!TestJSONParsing())
    {
        Print("ERRO: Teste básico de JSON falhou");
        return false;
    }
    
    // Fazer parse do JSON principal
    if (!m_config.Deserialize(json_content))
    {
        Print("ERRO: Falha ao fazer parse do JSON principal");
        Print("Primeiros 200 caracteres do JSON:");
        Print(StringSubstr(json_content, 0, 200));
        return false;
    }

    Print("JSON parseado com sucesso!");
    Print("Configuração carregada - Size: ", m_config.Size());

    // Extrair símbolos da configuração
    ArrayResize(m_symbols, 0);
    for (int i = 0; i < m_config.Size(); i++)
    {
        string symbol = m_config.children[i].key;
        if(StringLen(symbol) > 0)
        {
            ArrayResize(m_symbols, ArraySize(m_symbols) + 1);
            m_symbols[ArraySize(m_symbols) - 1] = symbol;
            Print("Símbolo encontrado no JSON: ", symbol);
        }
    }

    Print("Total de símbolos extraídos: ", ArraySize(m_symbols));
    return ArraySize(m_symbols) > 0;
}

//+------------------------------------------------------------------+
//| Carregar configuração do arquivo JSON                           |
//+------------------------------------------------------------------+
bool CConfigManager::LoadConfigFromFile(string file_path)
{
    Print("Tentando abrir arquivo: ", file_path);

    int file_handle = OpenConfigFile(file_path);
    if(file_handle == INVALID_HANDLE)
        return false;

    // Obter tamanho do arquivo
    ulong file_size = FileSize(file_handle);
    Print("Tamanho do arquivo: ", file_size, " bytes");
    
    // Resetar posição do arquivo
    FileSeek(file_handle, 0, SEEK_SET);
    
    // Ler arquivo linha por linha (método mais confiável)
    string json_content = "";
    int lines_read = 0;
    
    Print("Lendo arquivo linha por linha...");
    while (!FileIsEnding(file_handle))
    {
        string line = FileReadString(file_handle);
        if(StringLen(line) > 0)
        {
            json_content += line;
            Print("Linha ", lines_read + 1, " (", StringLen(line), " chars): ", StringSubstr(line, 0, MathMin(60, StringLen(line))));
        }
        lines_read++;
        
        // Segurança para evitar loop infinito
        if(lines_read > 1000)
        {
            Print("AVISO: Muitas linhas lidas, interrompendo");
            break;
        }
    }
    Print("Total de linhas lidas: ", lines_read);

    FileClose(file_handle);
    
    Print("Arquivo JSON carregado:");
    Print("- Caracteres totais: ", StringLen(json_content));
    
    if(StringLen(json_content) == 0)
    {
        Print("ERRO: Nenhum conteúdo lido do arquivo");
        return false;
    }
    
    // Verificar se temos caracteres válidos
    string first_chars = StringSubstr(json_content, 0, MathMin(100, StringLen(json_content)));
    Print("- Primeiros 100 caracteres: '", first_chars, "'");
    
    // Mostrar os últimos caracteres também
    if(StringLen(json_content) > 100)
    {
        string last_chars = StringSubstr(json_content, StringLen(json_content) - 50);
        Print("- Últimos 50 caracteres: '", last_chars, "'");
    }
    
    // Verificar se começa com { (JSON válido)
    if(StringLen(json_content) > 0)
    {
        ushort first_char = StringGetCharacter(json_content, 0);
        ushort last_char = StringGetCharacter(json_content, StringLen(json_content) - 1);
        Print("- Primeiro caractere (código): ", first_char, " '", CharToString((char)first_char), "'");
        Print("- Último caractere (código): ", last_char, " '", CharToString((char)last_char), "'");
        
        if(first_char == '{' || first_char == 123)
        {
            Print("- Arquivo parece ser JSON válido");
        }
        else
        {
            Print("- AVISO: Arquivo não parece começar com '{' - possível problema de encoding");
            
            // Tentar encontrar o primeiro '{'
            int brace_pos = StringFind(json_content, "{");
            if(brace_pos >= 0)
            {
                json_content = StringSubstr(json_content, brace_pos);
                Print("- JSON ajustado, novo tamanho: ", StringLen(json_content));
                Print("- Novos primeiros 50 caracteres: '", StringSubstr(json_content, 0, 50), "'");
            }
        }
    }

    return LoadConfig(json_content);
}

//+------------------------------------------------------------------+
//| Criar contextos baseados na configuração                        |
//+------------------------------------------------------------------+
bool CConfigManager::CreateContexts()
{
    Print("Criando contextos a partir da configuração JSON...");

    // Itera todos os símbolos configurados e, para cada um,
    // percorre dinamicamente as chaves de timeframe existentes
    // no nó do JSON. Isso permite adicionar novos timeframes ao
    // arquivo de configuração sem modificar o código fonte.

    for (int s = 0; s < ArraySize(m_symbols); s++)
    {
        string symbol = m_symbols[s];
        Print("Processando símbolo: ", symbol);

        CJAVal *symbol_config = m_config[symbol];
        if (symbol_config == NULL)
        {
            Print("ERRO: Configuração não encontrada para símbolo: ", symbol);
            continue;
        }
        
        Print("Configuração encontrada para símbolo: ", symbol, " com ", symbol_config.Size(), " timeframes");

        for (int t = 0; t < symbol_config.Size(); t++)
        {
            string tf_str = symbol_config.children[t].key;
            Print("Processando timeframe: ", tf_str);

            CJAVal *tf_config = symbol_config[tf_str];

            if (tf_config == NULL)
            {
                Print("Timeframe ", tf_str, " não encontrado para ", symbol);
                continue;
            }

            ENUM_TIMEFRAMES tf = StringToTimeframe(tf_str);
            if (tf == PERIOD_CURRENT)
            {
                Print("ERRO: TimeFrame inválido: ", tf_str);
                continue;
            }

            STimeframeConfig config = ParseTimeframeConfig(tf_config, tf);
            Print("TimeFrame ", tf_str, " - Enabled: ", config.enabled, " NumCandles: ", config.num_candles);

            if (!config.enabled)
            {
                Print("TimeFrame ", tf_str, " está desabilitado");
                continue;
            }

            // Criar novo contexto com lista de indicadores e priceactions
            TF_CTX *ctx = new TF_CTX(tf, config.num_candles,
                                    config.indicators, config.priceactions);
            if (ctx == NULL)
            {
                Print("ERRO: Falha ao criar contexto para ", symbol, " ", tf_str);
                continue;
            }

            if (!ctx.Init())
            {
                Print("ERRO: Falha ao inicializar contexto para ", symbol, " ", tf_str);
                delete ctx;
                continue;
            }

            // Adicionar aos arrays
            string key = CreateContextKey(symbol, tf);
            ArrayResize(m_contexts, ArraySize(m_contexts) + 1);
            ArrayResize(m_context_keys, ArraySize(m_context_keys) + 1);

            m_contexts[ArraySize(m_contexts) - 1] = ctx;
            m_context_keys[ArraySize(m_context_keys) - 1] = key;

            Print("Contexto criado com sucesso: ", key);
        }
    }

    Print("Total de contextos criados: ", ArraySize(m_contexts));
    return ArraySize(m_contexts) > 0;
}

//+------------------------------------------------------------------+
//| Obter contexto por símbolo e timeframe                          |
//+------------------------------------------------------------------+
TF_CTX *CConfigManager::GetContext(string symbol, ENUM_TIMEFRAMES timeframe)
{
    string key = CreateContextKey(symbol, timeframe);

    for (int i = 0; i < ArraySize(m_context_keys); i++)
    {
        if (m_context_keys[i] == key)
        {
            return m_contexts[i];
        }
    }

    return NULL;
}

//+------------------------------------------------------------------+
//| Verificar se contexto está habilitado                           |
//+------------------------------------------------------------------+
bool CConfigManager::IsContextEnabled(string symbol, ENUM_TIMEFRAMES timeframe)
{
    return GetContext(symbol, timeframe) != NULL;
}

//+------------------------------------------------------------------+
//| Obter símbolos configurados                                     |
//+------------------------------------------------------------------+
void CConfigManager::GetConfiguredSymbols(string &symbols[])
{
    ArrayResize(symbols, ArraySize(m_symbols));
    for (int i = 0; i < ArraySize(m_symbols); i++)
    {
        symbols[i] = m_symbols[i];
    }
}

//+------------------------------------------------------------------+
//| Obter todos os contextos de um símbolo                           |
//+------------------------------------------------------------------+
int CConfigManager::GetSymbolContexts(string symbol, TF_CTX *&contexts[], ENUM_TIMEFRAMES &timeframes[])
{
    ArrayResize(contexts, 0);
    ArrayResize(timeframes, 0);

    for (int i = 0; i < ArraySize(m_context_keys); i++)
    {
        string key = m_context_keys[i];
        if (StringFind(key, symbol + "_") == 0)
        {
            int pos = ArraySize(contexts);
            ArrayResize(contexts, pos + 1);
            ArrayResize(timeframes, pos + 1);
            contexts[pos] = m_contexts[i];

            string tf_str = StringSubstr(key, StringLen(symbol) + 1);
            timeframes[pos] = StringToTimeframe(tf_str);
        }
    }

    return ArraySize(contexts);
}

//+------------------------------------------------------------------+
//| Limpar recursos                                                  |
//+------------------------------------------------------------------+
void CConfigManager::Cleanup()
{
    for (int i = 0; i < ArraySize(m_contexts); i++)
    {
        if (m_contexts[i] != NULL)
        {
            delete m_contexts[i];
            m_contexts[i] = NULL;
        }
    }

    ArrayResize(m_contexts, 0);
    ArrayResize(m_context_keys, 0);
    ArrayResize(m_symbols, 0);
    m_config.Clear();
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Teste básico de JSON parsing                                    |
//+------------------------------------------------------------------+
bool CConfigManager::TestJSONParsing()
{
    string test_json = "{\"key\":\"value\"}";
    CJAVal test_config;
    
    bool result = test_config.Deserialize(test_json);
    if(result)
    {
        Print("Teste básico de JSON: SUCESSO");
        Print("Valor teste: ", test_config["test"].ToStr());
    }
    else
    {
        Print("Teste básico de JSON: FALHOU");
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Converter timeframe para string                                 |
//+------------------------------------------------------------------+
string CConfigManager::TimeframeToString(ENUM_TIMEFRAMES tf)
{
    switch (tf)
    {
    case PERIOD_M1: return "M1";
    case PERIOD_M5: return "M5";
    case PERIOD_M15: return "M15";
    case PERIOD_M30: return "M30";
    case PERIOD_H1: return "H1";
    case PERIOD_H4: return "H4";
    case PERIOD_D1: return "D1";
    default: return "";
    }
}

//+------------------------------------------------------------------+
//| Converter string para timeframe                                 |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES CConfigManager::StringToTimeframe(string tf_str)
{
    return ToTimeframe(tf_str);
}

//+------------------------------------------------------------------+
//| Converter string para método de média móvel                     |
//+------------------------------------------------------------------+
ENUM_MA_METHOD CConfigManager::StringToMAMethod(string method_str)
{
    return ToMaMethod(method_str);
}

//+------------------------------------------------------------------+
//| Converter string para price field do Estocástico                 |
//+------------------------------------------------------------------+
ENUM_STO_PRICE CConfigManager::StringToPriceField(string field_str)
{
    return ToPriceField(field_str);
}

//+------------------------------------------------------------------+
//| Converter string para applied price das Bandas de Bollinger      |
//+------------------------------------------------------------------+
ENUM_APPLIED_PRICE CConfigManager::StringToAppliedPrice(string price_str)
{
    return ToAppliedPrice(price_str);
}

//+------------------------------------------------------------------+
//| Converter string para modo de cálculo da VWAP                     |
//+------------------------------------------------------------------+
ENUM_VWAP_CALC_MODE CConfigManager::StringToVWAPCalcMode(string mode_str)
{
    return ToVWAPCalcMode(mode_str);
}

//+------------------------------------------------------------------+
//| Converter string para tipo de preço da VWAP                       |
//+------------------------------------------------------------------+
ENUM_VWAP_PRICE_TYPE CConfigManager::StringToVWAPPriceType(string type_str)
{
    return ToVWAPPriceType(type_str);
}

//+------------------------------------------------------------------+
//| Converter string para estilo de linha                            |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE CConfigManager::StringToLineStyle(string style_str)
{
    return ToLineStyle(style_str);
}

//+------------------------------------------------------------------+
//| Converter string para cor                                        |
//+------------------------------------------------------------------+
color CConfigManager::StringToColor(string color_str)
{
    return ToColor(color_str);
}

//+------------------------------------------------------------------+
//| Abrir arquivo de configuração com tentativas em diferentes       |
//| pastas e encodings                                               |
//+------------------------------------------------------------------+
int CConfigManager::OpenConfigFile(string file_path)
{
    int handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_ANSI);
    if(handle != INVALID_HANDLE)
    {
        Print("Arquivo encontrado na pasta local do EA (ANSI)");
        return handle;
    }

    Print("Arquivo não encontrado na pasta local, tentando pasta Common...");
    handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);
    if(handle != INVALID_HANDLE)
    {
        Print("Arquivo encontrado na pasta Common (ANSI)");
        return handle;
    }

    Print("Tentando com UTF-8...");
    handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
    {
        Print("ERRO: Arquivo não encontrado: ", file_path);
        Print("Verificar se arquivo existe em:");
        Print("1. Terminal_Data_Folder\\MQL5\\Files\\", file_path);
        Print("2. Common_Data_Folder\\Files\\", file_path);
    }
    else
    {
        Print("Arquivo encontrado na pasta Common (UTF-8)");
    }

    return handle;
}

//+------------------------------------------------------------------+
//| Preencher campos basicos de um indicador                          |
//+------------------------------------------------------------------+
void CConfigManager::FillIndicatorBase(CIndicatorConfig &cfg, CJAVal *node, string type)
{
    cfg.name = (*node)["name"].ToStr();
    cfg.type = type;
    cfg.enabled = (*node)["enabled"].ToBool();
    cfg.attach_chart = (*node)["attach_chart"].ToBool(); // Nova linha para ler attach_chart
}

//+------------------------------------------------------------------+
//| Preencher campos basicos de uma priceaction                      |
//+------------------------------------------------------------------+
void CConfigManager::FillPriceActionBase(CPriceActionConfig &cfg, CJAVal *node, string type)
{
    cfg.name = (*node)["name"].ToStr();
    cfg.type = type;
    cfg.enabled = (*node)["enabled"].ToBool();
}

//+------------------------------------------------------------------+
//| Criar configuracao de indicador                                   |
//+------------------------------------------------------------------+
CIndicatorConfig *CConfigManager::CreateIndicatorConfig(CJAVal *ind)
{
    if(ind==NULL)
        return NULL;

    string type = ind["type"].ToStr();
    string col = "";

    if(type=="MA")
    {
        CMAConfig *p=new CMAConfig();
        FillIndicatorBase(*p, ind, type);
        p.period=(int)ind["period"].ToInt();
        p.method=StringToMAMethod(ind["method"].ToStr());
        return p;
    }
    else if(type=="STO")
    {
        CStochasticConfig *p=new CStochasticConfig();
        FillIndicatorBase(*p, ind, type);
        p.period=(int)ind["period"].ToInt();
        p.dperiod=(int)ind["dperiod"].ToInt();
        p.slowing=(int)ind["slowing"].ToInt();
        p.method=StringToMAMethod(ind["method"].ToStr());
        p.price_field=StringToPriceField(ind["price_field"].ToStr());
        return p;
    }
    else if(type=="VOL")
    {
        CVolumeConfig *p=new CVolumeConfig();
        FillIndicatorBase(*p, ind, type);
        p.shift=(int)ind["shift"].ToInt();
        return p;
    }
    else if(type=="VWAP")
    {
        CVWAPConfig *p=new CVWAPConfig();
        FillIndicatorBase(*p, ind, type);
        p.period=(int)ind["period"].ToInt();
        p.method=StringToMAMethod(ind["method"].ToStr());
        p.calc_mode=StringToVWAPCalcMode(ind["calc_mode"].ToStr());
        p.session_tf=StringToTimeframe(ind["session_tf"].ToStr());
        p.price_type=StringToVWAPPriceType(ind["price_type"].ToStr());
        string start_str=ind["start_time"].ToStr();
        if(StringLen(start_str)>0) p.start_time=StringToTime(start_str);
        col=ind["Color"].ToStr();
        p.line_color=StringToColor(col);
        p.line_style=StringToLineStyle(ind["Style"].ToStr());
        p.line_width=(int)ind["Width"].ToInt();
        return p;
    }
    else if(type=="BOLL")
    {
        CBollingerConfig *p=new CBollingerConfig();
        FillIndicatorBase(*p, ind, type);
        p.period=(int)ind["period"].ToInt();
        p.shift=(int)ind["shift"].ToInt();
        p.deviation=ind["deviation"].ToDbl();
        p.applied_price=StringToAppliedPrice(ind["applied_price"].ToStr());
        return p;
    }
    else if(type=="FIBO")
    {
        CFiboConfig *p=new CFiboConfig();
        FillIndicatorBase(*p, ind, type);
        p.period=(int)ind["period"].ToInt();
        p.level_1=ind["Level_1"].ToDbl();
        p.level_2=ind["Level_2"].ToDbl();
        p.level_3=ind["Level_3"].ToDbl();
        p.level_4=ind["Level_4"].ToDbl();
        p.level_5=ind["Level_5"].ToDbl();
        p.level_6=ind["Level_6"].ToDbl();
        col=ind["LevelsColor"].ToStr();
        p.levels_color=StringToColor(col);
        p.levels_style=StringToLineStyle(ind["LevelsStyle"].ToStr());
        p.levels_width=(int)ind["LevelsWidth"].ToInt();
        p.ext_1=ind["Ext_1"].ToDbl();
        p.ext_2=ind["Ext_2"].ToDbl();
        p.ext_3=ind["Ext_3"].ToDbl();
        col=ind["ExtensionsColor"].ToStr();
        p.extensions_color=StringToColor(col);
        p.extensions_style=StringToLineStyle(ind["ExtensionsStyle"].ToStr());
        p.extensions_width=(int)ind["ExtensionsWidth"].ToInt();
        col=ind["ParallelColor"].ToStr();
        p.parallel_color=StringToColor(col);
        p.parallel_style=StringToLineStyle(ind["ParallelStyle"].ToStr());
        p.parallel_width=(int)ind["ParallelWidth"].ToInt();
        p.show_labels=ind["ShowLabels"].ToBool();
        col=ind["LabelsColor"].ToStr();
        p.labels_color=StringToColor(col);
        p.labels_font_size=(int)ind["LabelsFontSize"].ToInt();
        string font=ind["LabelsFont"].ToStr();
        if(StringLen(font)>0) p.labels_font=font;
        return p;
    }

    return NULL;
}

//+------------------------------------------------------------------+
//| Criar configuracao de priceaction                                 |
//+------------------------------------------------------------------+
CPriceActionConfig *CConfigManager::CreatePriceActionConfig(CJAVal *pa, ENUM_TIMEFRAMES ctx_tf)
{
    if(pa==NULL)
        return NULL;

    string type = pa["type"].ToStr();

    if(type=="TRENDLINE")
    {
        CTrendLineConfig *p=new CTrendLineConfig();
        FillPriceActionBase(*p, pa, type);
        p.period=(int)pa["period"].ToInt();
        p.pivot_left=(int)pa["pivot_left"].ToInt();
        p.pivot_right=(int)pa["pivot_right"].ToInt();
        p.draw_lta=pa["draw_lta"].ToBool();
        p.draw_ltb=pa["draw_ltb"].ToBool();
        p.lta_color=StringToColor(pa["lta_color"].ToStr());
        p.ltb_color=StringToColor(pa["ltb_color"].ToStr());
        p.lta_style=StringToLineStyle(pa["lta_style"].ToStr());
        p.ltb_style=StringToLineStyle(pa["ltb_style"].ToStr());
        p.lta_width=(int)pa["lta_width"].ToInt();
        p.ltb_width=(int)pa["ltb_width"].ToInt();
        p.extend_right=pa["extend_right"].ToBool();
        p.alert_tf=StringToTimeframe(pa["alert_tf"].ToStr());
      p.min_angle=pa["min_angle"].ToDbl();

      p.candles_lookback=(int)pa["trendline_candles_lookback"].ToInt();
      CJAVal *flags=pa["trendline_status_flags"];
      if(flags!=NULL)
        {
         p.status_flags.enable_body_cross=flags["enable_body_cross"].ToBool();
         p.status_flags.enable_between_ltas=flags["enable_between_ltas"].ToBool();
         p.status_flags.enable_between_ltbs=flags["enable_between_ltbs"].ToBool();
         p.status_flags.enable_distance_points=flags["enable_distance_points"].ToBool();
        }

      CJAVal *ctx=pa["trendline_context_analysis"];
      if(ctx!=NULL)
        {
         p.context_analysis.enabled=ctx["enabled"].ToBool();
         p.context_analysis.lookback=(int)ctx["lookback"].ToInt();
         p.context_analysis.trend_threshold=ctx["trend_threshold"].ToDbl();
         p.context_analysis.consolidation_threshold=ctx["consolidation_threshold"].ToDbl();
        }

      CJAVal *adv=pa["trendline_advanced_features"];
      if(adv!=NULL)
        {
         p.advanced_features.detect_fakeout=adv["detect_fakeout"].ToBool();
         p.advanced_features.count_touches=adv["count_touches"].ToBool();
         p.advanced_features.touch_tolerance_points=adv["touch_tolerance_points"].ToDbl();
         string mode=adv["status_evaluate_mode"].ToStr();
         if(StringLen(mode)>0) p.advanced_features.status_evaluate_mode=mode;
         p.advanced_features.register_resets=adv["register_resets"].ToBool();
        }

        if(p.alert_tf==PERIOD_CURRENT)   p.alert_tf=ctx_tf;
        return p;
    }
    else if(type=="SUPRES")
    {
        CSupResConfig *p=new CSupResConfig();
        FillPriceActionBase(*p, pa, type);
        p.period=(int)pa["period"].ToInt();
        p.draw_sup=pa["draw_sup"].ToBool();
        p.draw_res=pa["draw_res"].ToBool();
        p.sup_color=StringToColor(pa["sup_color"].ToStr());
        p.res_color=StringToColor(pa["res_color"].ToStr());
        p.sup_style=StringToLineStyle(pa["sup_style"].ToStr());
        p.res_style=StringToLineStyle(pa["res_style"].ToStr());
        p.sup_width=(int)pa["sup_width"].ToInt();
        p.res_width=(int)pa["res_width"].ToInt();
        p.extend_right=pa["extend_right"].ToBool();
        p.show_labels=pa["show_labels"].ToBool();
        p.touch_lookback=(int)pa["touch_lookback"].ToInt();
        p.touch_tolerance=pa["touch_tolerance"].ToDbl();
        p.zone_range=pa["zone_range"].ToDbl();
        p.max_zones_to_draw=(int)pa["max_zones_to_draw"].ToInt();
        p.min_touches=(int)pa["min_touches"].ToInt();
        p.validation=(ENUM_SUPRES_VALIDATION)pa["validation"].ToInt();
        p.alert_tf=StringToTimeframe(pa["alert_tf"].ToStr());
        if(p.alert_tf==PERIOD_CURRENT) p.alert_tf=ctx_tf;
        return p;
    }

    return NULL;
}

//+------------------------------------------------------------------+
//| Fazer parse da configuração do timeframe                        |
//+------------------------------------------------------------------+
STimeframeConfig CConfigManager::ParseTimeframeConfig(CJAVal *tf_config, ENUM_TIMEFRAMES ctx_tf)
{
    STimeframeConfig config;
    
    if (tf_config == NULL)
    {
        Print("ERRO: tf_config é NULL");
        config.enabled = false;
        config.num_candles = 0;
        return config;
    }

    // Valores básicos
    config.enabled = tf_config["enabled"].ToBool();
    config.num_candles = (int)tf_config["num_candles"].ToInt();

    Print("Parseando timeframe - Enabled: ", config.enabled, " NumCandles: ", config.num_candles);

    // Lista de indicadores
    CJAVal *ind_array = tf_config["indicators"];
    ArrayResize(config.indicators,0);
    ArrayResize(config.priceactions,0);

    if(ind_array != NULL)
    {
        for(int i=0;i<ind_array.Size();i++)
        {
            CIndicatorConfig *icfg = CreateIndicatorConfig((*ind_array)[i]);
            if(icfg==NULL)
                continue;

            int pos = ArraySize(config.indicators);
            ArrayResize(config.indicators,pos+1);
            config.indicators[pos]=icfg;

            Print("Indicador lido: ", icfg.name, " Tipo: ", icfg.type, " Enabled: ", icfg.enabled);
        }
    }
    else
    {
        Print("AVISO: Nenhum indicador configurado");
    }

    // Lista de priceactions
    CJAVal *pa_array = tf_config["priceaction"];
    if(pa_array != NULL)
    {
        for(int i=0;i<pa_array.Size();i++)
        {
            CPriceActionConfig *pcfg = CreatePriceActionConfig((*pa_array)[i], ctx_tf);
            if(pcfg==NULL)
                continue;

            int pos=ArraySize(config.priceactions);
            ArrayResize(config.priceactions,pos+1);
            config.priceactions[pos]=pcfg;
            Print("PriceAction lido: ", pcfg.name, " Tipo: ", pcfg.type, " Enabled: ", pcfg.enabled);
        }
    }
    else
    {
        Print("AVISO: Nenhum priceaction configurado");
    }

    return config;
}

//+------------------------------------------------------------------+
//| Criar chave do contexto                                         |
//+------------------------------------------------------------------+
string CConfigManager::CreateContextKey(string symbol, ENUM_TIMEFRAMES tf)
{
    return symbol + "_" + TimeframeToString(tf);
}