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
    STimeframeConfig ParseTimeframeConfig(CJAVal *tf_config);
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
    
    // Primeiro tentar na pasta local do EA com encoding ANSI
    int file_handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_ANSI);
    
    if (file_handle == INVALID_HANDLE)
    {
        Print("Arquivo não encontrado na pasta local, tentando pasta Common...");
        // Tentar com FILE_COMMON e ANSI
        file_handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);
        if (file_handle == INVALID_HANDLE)
        {
            // Última tentativa com UTF-8
            Print("Tentando com UTF-8...");
            file_handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON);
            if (file_handle == INVALID_HANDLE)
            {
                Print("ERRO: Arquivo não encontrado: ", file_path);
                Print("Verificar se arquivo existe em:");
                Print("1. Terminal_Data_Folder\\MQL5\\Files\\", file_path);
                Print("2. Common_Data_Folder\\Files\\", file_path);
                return false;
            }
            else
            {
                Print("Arquivo encontrado na pasta Common (UTF-8)");
            }
        }
        else
        {
            Print("Arquivo encontrado na pasta Common (ANSI)");
        }
    }
    else
    {
        Print("Arquivo encontrado na pasta local do EA (ANSI)");
    }

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

            STimeframeConfig config = ParseTimeframeConfig(tf_config);
            Print("TimeFrame ", tf_str, " - Enabled: ", config.enabled, " NumCandles: ", config.num_candles);

            if (!config.enabled)
            {
                Print("TimeFrame ", tf_str, " está desabilitado");
                continue;
            }

            ENUM_TIMEFRAMES tf = StringToTimeframe(tf_str);
            if (tf == PERIOD_CURRENT)
            {
                Print("ERRO: TimeFrame inválido: ", tf_str);
                continue;
            }

            // Criar novo contexto com lista de indicadores
            TF_CTX *ctx = new TF_CTX(tf, config.num_candles, config.indicators);
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
    if (tf_str == "M1") return PERIOD_M1;
    if (tf_str == "M5") return PERIOD_M5;
    if (tf_str == "M15") return PERIOD_M15;
    if (tf_str == "M30") return PERIOD_M30;
    if (tf_str == "H1") return PERIOD_H1;
    if (tf_str == "H4") return PERIOD_H4;
    if (tf_str == "D1") return PERIOD_D1;
    return PERIOD_CURRENT;
}

//+------------------------------------------------------------------+
//| Converter string para método de média móvel                     |
//+------------------------------------------------------------------+
ENUM_MA_METHOD CConfigManager::StringToMAMethod(string method_str)
{
    if (method_str == "SMA") return MODE_SMA;
    if (method_str == "EMA") return MODE_EMA;
    if (method_str == "SMMA") return MODE_SMMA;
    if (method_str == "LWMA") return MODE_LWMA;
    return MODE_SMA;
}

//+------------------------------------------------------------------+
//| Converter string para price field do Estocástico                 |
//+------------------------------------------------------------------+
ENUM_STO_PRICE CConfigManager::StringToPriceField(string field_str)
{
    if(field_str == "CLOSECLOSE" || field_str == "CLOSE_CLOSE")
        return STO_CLOSECLOSE;
    return STO_LOWHIGH;
}

//+------------------------------------------------------------------+
//| Fazer parse da configuração do timeframe                        |
//+------------------------------------------------------------------+
STimeframeConfig CConfigManager::ParseTimeframeConfig(CJAVal *tf_config)
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

    if(ind_array != NULL)
    {
        for(int i=0;i<ind_array.Size();i++)
        {
            CJAVal *ind = (*ind_array)[i];
            if(ind==NULL) continue;

            SIndicatorConfig icfg;
            icfg.name    = ind["name"].ToStr();
            icfg.type    = ind["type"].ToStr();
            icfg.period  = (int)ind["period"].ToInt();
            icfg.method  = StringToMAMethod(ind["method"].ToStr());
            icfg.dperiod = (int)ind["dperiod"].ToInt();
            icfg.slowing = (int)ind["slowing"].ToInt();
            icfg.price_field = StringToPriceField(ind["price_field"].ToStr());
            icfg.enabled = ind["enabled"].ToBool();

            int pos = ArraySize(config.indicators);
            ArrayResize(config.indicators,pos+1);
            config.indicators[pos]=icfg;

            Print("Indicador lido: ", icfg.name, " Tipo: ", icfg.type, " Period: ", icfg.period, " Enabled: ", icfg.enabled);
        }
    }
    else
    {
        Print("AVISO: Nenhum indicador configurado");
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