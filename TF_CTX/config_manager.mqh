//+------------------------------------------------------------------+
//|                                           config_manager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//| Versão simplificada para configuração hardcoded                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

// Redefinir o macro DEBUG_PRINT_KEY para evitar warnings
#ifdef DEBUG_PRINT_KEY
#undef DEBUG_PRINT_KEY
#endif
#define DEBUG_PRINT_KEY()

#include "../utils/JAson.mqh"
#include "tf_ctx.mqh"

// Função auxiliar para remover espaços em branco de uma string
string TrimString(string value)
{
    StringTrimLeft(value);
    StringTrimRight(value);
    return value;
}

// Remove UTF-8 BOM if present
string RemoveBOM(string value)
{
    if(StringLen(value) > 0 && StringGetCharacter(value,0) == 0xFEFF)
        return StringSubstr(value,1);
    return value;
}

//+------------------------------------------------------------------+
//| Estrutura para configuração de média móvel                      |
//+------------------------------------------------------------------+
struct SMovingAverageConfig
{
    int period;
    ENUM_MA_METHOD method;
    bool enabled;
};

//+------------------------------------------------------------------+
//| Estrutura para configuração de timeframe                        |
//+------------------------------------------------------------------+
struct STimeframeConfig
{
    bool enabled;
    int num_candles;
    SMovingAverageConfig ema9;
    SMovingAverageConfig ema21;
    SMovingAverageConfig ema50;
    SMovingAverageConfig sma200;
};

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
    STimeframeConfig ParseTimeframeConfig(CJAVal *tf_config);
    string CreateContextKey(string symbol, ENUM_TIMEFRAMES tf);
    bool CreateHardcodedConfig();
    bool TestJSONParsing();
    
public:
    // Construtor e Destrutor
    CConfigManager();
    ~CConfigManager();

    // Inicialização
    bool Init(string json_content);
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
//| Inicialização com string JSON                                   |
//+------------------------------------------------------------------+
bool CConfigManager::Init(string json_content)
{
    Print("Inicializando ConfigManager com JSON hardcoded...");
    
    if (!LoadConfig(json_content))
    {
        Print("ERRO: Falha ao carregar configuração JSON");
        Print("FALLBACK: Tentando configuração hardcoded...");
        return CreateHardcodedConfig();
    }

    if (!CreateContexts())
    {
        Print("ERRO: Falha ao criar contextos do JSON");
        Print("FALLBACK: Tentando configuração hardcoded...");
        return CreateHardcodedConfig();
    }

    m_initialized = true;
    Print("ConfigManager inicializado com sucesso. Símbolos carregados: ", ArraySize(m_symbols));
    Print("Contextos criados: ", ArraySize(m_contexts));
    return true;
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
        Print("FALLBACK: Usando configuração hardcoded...");
        return CreateHardcodedConfig();
    }

    if (!CreateContexts())
    {
        Print("ERRO: Falha ao criar contextos");
        Print("FALLBACK: Usando configuração hardcoded...");
        return CreateHardcodedConfig();
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
    json_content = RemoveBOM(TrimString(json_content));
    Print("Tamanho do JSON: ", StringLen(json_content), " caracteres");
    
    // Testar parsing básico primeiro
    if(!TestJSONParsing())
    {
        Print("ERRO: Teste básico de JSON falhou");
        return false;
    }
    
    if (!m_config.Deserialize(json_content, CP_UTF8))
    {
        Print("ERRO: Falha ao fazer parse do JSON");
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
            Print("Símbolo encontrado: ", symbol);
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
    // Abrir o arquivo como texto em UTF-8
    int file_handle = FileOpen(file_path, FILE_READ | FILE_TXT, '\n', CP_UTF8);
    
    if (file_handle == INVALID_HANDLE)
    {
        // Tentar no diretório comum de arquivos
        file_handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON, '\n', CP_UTF8);
        if (file_handle == INVALID_HANDLE)
        {
            Print("ERRO: Arquivo não encontrado: ", file_path);
            return false;
        }
        else
        {
            Print("Arquivo encontrado na pasta Common");
        }
    }
    else
    {
        Print("Arquivo encontrado na pasta local");
    }

    // Ler o conteúdo inteiro do arquivo
    int file_size = (int)FileSize(file_handle);
    FileSeek(file_handle, 0, SEEK_SET);
    string json_content = FileReadString(file_handle, file_size);

    FileClose(file_handle);

    json_content = RemoveBOM(TrimString(json_content));
    Print("Arquivo carregado com ", StringLen(json_content), " caracteres");

    return LoadConfig(json_content);
}

//+------------------------------------------------------------------+
//| Criar configuração hardcoded como fallback                       |
//+------------------------------------------------------------------+
bool CConfigManager::CreateHardcodedConfig()
{
    Print("Criando configuração hardcoded...");
    
    // Limpar arrays
    ArrayResize(m_symbols, 0);
    ArrayResize(m_contexts, 0);
    ArrayResize(m_context_keys, 0);
    
    // Adicionar símbolos hardcoded
    string hardcoded_symbols[] = {"WIN$N"};
    
    for(int s = 0; s < ArraySize(hardcoded_symbols); s++)
    {
        string symbol = hardcoded_symbols[s];
        
        // Adicionar símbolo
        ArrayResize(m_symbols, ArraySize(m_symbols) + 1);
        m_symbols[ArraySize(m_symbols) - 1] = symbol;
        Print("Símbolo hardcoded adicionado: ", symbol);
        
        // Criar contexto D1
        TF_CTX* ctx_d1 = new TF_CTX(PERIOD_D1, 9);
        if(ctx_d1 != NULL && ctx_d1.Init())
        {
            string key_d1 = CreateContextKey(symbol, PERIOD_D1);
            ArrayResize(m_contexts, ArraySize(m_contexts) + 1);
            ArrayResize(m_context_keys, ArraySize(m_context_keys) + 1);
            
            m_contexts[ArraySize(m_contexts) - 1] = ctx_d1;
            m_context_keys[ArraySize(m_context_keys) - 1] = key_d1;
            
            Print("Contexto hardcoded criado: ", key_d1);
        }
        
        // Criar contexto H4
        TF_CTX* ctx_h4 = new TF_CTX(PERIOD_H4, 18);
        if(ctx_h4 != NULL && ctx_h4.Init())
        {
            string key_h4 = CreateContextKey(symbol, PERIOD_H4);
            ArrayResize(m_contexts, ArraySize(m_contexts) + 1);
            ArrayResize(m_context_keys, ArraySize(m_context_keys) + 1);
            
            m_contexts[ArraySize(m_contexts) - 1] = ctx_h4;
            m_context_keys[ArraySize(m_context_keys) - 1] = key_h4;
            
            Print("Contexto hardcoded criado: ", key_h4);
        }
    }
    
    Print("Total de contextos hardcoded criados: ", ArraySize(m_contexts));
    m_initialized = true;
    return ArraySize(m_contexts) > 0;
}

//+------------------------------------------------------------------+
//| Criar contextos baseados na configuração                        |
//+------------------------------------------------------------------+
bool CConfigManager::CreateContexts()
{
    Print("Criando contextos a partir da configuração JSON...");
    
    string timeframes[] = {"D1", "H4", "H1", "M30", "M15", "M5", "M1"};

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

        for (int t = 0; t < ArraySize(timeframes); t++)
        {
            string tf_str = timeframes[t];
            CJAVal *tf_config = symbol_config[tf_str];

            if (tf_config == NULL)
                continue;

            STimeframeConfig config = ParseTimeframeConfig(tf_config);

            if (!config.enabled)
                continue;

            ENUM_TIMEFRAMES tf = StringToTimeframe(tf_str);
            if (tf == PERIOD_CURRENT)
                continue;

            // Criar novo contexto
            TF_CTX *ctx = new TF_CTX(tf, config.num_candles);
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

            Print("Contexto criado: ", key);
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
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Teste básico de JSON parsing                                    |
//+------------------------------------------------------------------+
bool CConfigManager::TestJSONParsing()
{
    string test_json = "{\"test\":\"value\"}";
    CJAVal test_config;
    
    bool result = test_config.Deserialize(test_json);
    if(result)
    {
        Print("Teste básico de JSON: SUCESSO");
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
//| Fazer parse da configuração do timeframe                        |
//+------------------------------------------------------------------+
STimeframeConfig CConfigManager::ParseTimeframeConfig(CJAVal *tf_config)
{
    STimeframeConfig config;
    
    if (tf_config == NULL)
    {
        config.enabled = false;
        config.num_candles = 0;
        return config;
    }

    // Valores básicos
    config.enabled = tf_config["enabled"].ToBool();
    config.num_candles = (int)tf_config["num_candles"].ToInt();

    // Configurações de médias móveis
    CJAVal *ma_config = tf_config["moving_averages"];
    
    if (ma_config != NULL)
    {
        // EMA9
        CJAVal *ema9 = ma_config["ema9"];
        if (ema9 != NULL)
        {
            config.ema9.period = (int)ema9["period"].ToInt();
            config.ema9.method = StringToMAMethod(ema9["method"].ToStr());
            config.ema9.enabled = ema9["enabled"].ToBool();
        }

        // EMA21
        CJAVal *ema21 = ma_config["ema21"];
        if (ema21 != NULL)
        {
            config.ema21.period = (int)ema21["period"].ToInt();
            config.ema21.method = StringToMAMethod(ema21["method"].ToStr());
            config.ema21.enabled = ema21["enabled"].ToBool();
        }

        // EMA50
        CJAVal *ema50 = ma_config["ema50"];
        if (ema50 != NULL)
        {
            config.ema50.period = (int)ema50["period"].ToInt();
            config.ema50.method = StringToMAMethod(ema50["method"].ToStr());
            config.ema50.enabled = ema50["enabled"].ToBool();
        }

        // SMA200
        CJAVal *sma200 = ma_config["sma200"];
        if (sma200 != NULL)
        {
            config.sma200.period = (int)sma200["period"].ToInt();
            config.sma200.method = StringToMAMethod(sma200["method"].ToStr());
            config.sma200.enabled = sma200["enabled"].ToBool();
        }
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