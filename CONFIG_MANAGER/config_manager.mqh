//+------------------------------------------------------------------+
//|                                           config_manager.mqh     |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "CopyrightF 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"


#include "../utils/JAson.mqh"
#include "../utils/conversion.mqh"

#include "submodules/tf_ctx_parser/tf_ctx_parser.mqh"
#include "submodules/strategy_parser/strategy_ctx_parser.mqh"

#include "../STRATEGIES/strategy_ctx.mqh"
#include "../TF_CTX/tf_ctx.mqh"

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
    CTimeframeConfigParser tf_ctx_parser;

    // Métodos privados
    bool LoadConfig(string json_content);
    bool LoadConfigFromFile(string file_path);
    bool CreateContexts();
    string TimeframeToString(ENUM_TIMEFRAMES tf);
    string CreateContextKey(string symbol, ENUM_TIMEFRAMES tf);
    int OpenConfigFile(string file_path);
    bool TestJSONParsing();
    bool ValidateNewStructure(); // Novo método para validar estrutura

    //--- STRATEGY_CTX Related Members
    STRATEGY_CTX *m_strategy_contexts[];
    string m_strategy_keys[];
    CStrategyConfigParser strategy_ctx_parser;

    //--- STRATEGY_CTX Related Methods
    bool CreateStrategyContexts();
    string CreateStrategyKey(string setup_name);

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

    //--- STRATEGY_CTX Public Methods
    STRATEGY_CTX *GetStrategyContext(string setup_name);
    bool IsStrategySetupEnabled(string setup_name);
    void GetConfiguredStrategySetups(string &setups[]);
    int GetStrategyContexts(STRATEGY_CTX *&contexts[], string &setup_names[]);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CConfigManager::CConfigManager()
{
    m_initialized = false;
    // Initialize symbol array
    ArrayResize(m_symbols, 0);

    // Initialize TF_CTX arrays
    ArrayResize(m_contexts, 0);
    ArrayResize(m_context_keys, 0);

    // Initialize STRATEGY_CTX arrays
    ArrayResize(m_strategy_contexts, 0);
    ArrayResize(m_strategy_keys, 0);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CConfigManager::~CConfigManager()
{
    Cleanup();
    // Cleanup do singleton factory
    CIndicatorFactory::Cleanup();
    CStrategyFactory::Cleanup();
}

//+------------------------------------------------------------------+
//| Inicialização do gerenciador com arquivo                        |
//+------------------------------------------------------------------+
bool CConfigManager::InitFromFile(string file_path)
{
    Print("=== INICIALIZANDO CONFIG MANAGER ===");
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

    if (!CreateStrategyContexts())
    {
        Print("ERRO: Falha ao criar contextos de estratégias");
        return false;
    }
    /***
     * Novos parsers devem ser chamados aqui
     *
     * ex. futuramente o parser para confluencias/regras/riscos e etc
     *
     * ***/

    m_initialized = true;
    Print("=== CONFIG MANAGER INICIALIZADO ===");
    Print("Símbolos carregados: ", ArraySize(m_symbols));
    Print("Contextos criados: ", ArraySize(m_contexts));
    Print("Contextos de estratégia criados: ", ArraySize(m_strategy_contexts));
    return true;
}

//+------------------------------------------------------------------+
//| Carregar configuração do JSON                                   |
//+------------------------------------------------------------------+
bool CConfigManager::LoadConfig(string json_content)
{
    Print("=== PARSING JSON ===");
    Print("Tamanho do JSON: ", StringLen(json_content), " caracteres");

    // Limpar configuração anterior
    m_config.Clear();

    // Testar parsing básico primeiro
    if (!TestJSONParsing())
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

    // Validar nova estrutura
    if (!ValidateNewStructure())
    {
        Print("ERRO: Estrutura JSON inválida");
        return false;
    }

    // Extrair símbolos da nova estrutura
    ArrayResize(m_symbols, 0);

    CJAVal *symbols_array = m_config["SYMBOLS"];
    if (symbols_array == NULL)
    {
        Print("ERRO: Array SYMBOLS não encontrado");
        return false;
    }

    Print("Encontrados ", symbols_array.Size(), " objetos no array SYMBOLS");

    // Percorrer cada objeto no array SYMBOLS
    for (int i = 0; i < symbols_array.Size(); i++)
    {
        CJAVal *symbol_obj = &symbols_array.children[i];

        // Cada objeto contém um símbolo como chave
        for (int j = 0; j < symbol_obj.Size(); j++)
        {
            string symbol = symbol_obj.children[j].key;
            if (StringLen(symbol) > 0)
            {
                ArrayResize(m_symbols, ArraySize(m_symbols) + 1);
                m_symbols[ArraySize(m_symbols) - 1] = symbol;
                Print("Símbolo encontrado: ", symbol);
            }
        }
    }

    Print("Total de símbolos extraídos: ", ArraySize(m_symbols));
    return ArraySize(m_symbols) > 0;
}

//+------------------------------------------------------------------+
//| Validar nova estrutura JSON                                     |
//+------------------------------------------------------------------+
bool CConfigManager::ValidateNewStructure()
{
    // Verificar se existe a chave SYMBOLS
    if (!m_config.HasKey("SYMBOLS"))
    {
        Print("ERRO: Chave 'SYMBOLS' não encontrada no JSON");
        return false;
    }

    CJAVal *symbols_array = m_config["SYMBOLS"];
    if (symbols_array == NULL)
    {
        Print("ERRO: SYMBOLS é nulo");
        return false;
    }

    if (symbols_array.Size() == 0)
    {
        Print("ERRO: Array SYMBOLS está vazio");
        return false;
    }

    Print("Estrutura JSON validada: ", symbols_array.Size(), " objetos encontrados no array SYMBOLS");
    return true;
}

//+------------------------------------------------------------------+
//| Carregar configuração do arquivo JSON                           |
//+------------------------------------------------------------------+
bool CConfigManager::LoadConfigFromFile(string file_path)
{
    Print("=== CARREGANDO ARQUIVO ===");
    Print("Arquivo: ", file_path);

    int file_handle = OpenConfigFile(file_path);
    if (file_handle == INVALID_HANDLE)
        return false;

    // Obter tamanho do arquivo
    ulong file_size = FileSize(file_handle);
    Print("Tamanho do arquivo: ", file_size, " bytes");

    // Resetar posição do arquivo
    FileSeek(file_handle, 0, SEEK_SET);

    // Ler arquivo linha por linha (método mais confiável)
    string json_content = "";
    int lines_read = 0;

    while (!FileIsEnding(file_handle))
    {
        string line = FileReadString(file_handle);
        if (StringLen(line) > 0)
        {
            json_content += line;
        }
        lines_read++;

        // Segurança para evitar loop infinito
        if (lines_read > 1000)
        {
            Print("AVISO: Muitas linhas lidas, interrompendo");
            break;
        }
    }

    FileClose(file_handle);

    Print("Arquivo carregado:");
    Print("- Linhas lidas: ", lines_read);
    Print("- Caracteres totais: ", StringLen(json_content));

    if (StringLen(json_content) == 0)
    {
        Print("ERRO: Nenhum conteúdo lido do arquivo");
        return false;
    }

    // Verificar se começa com { (JSON válido)
    if (StringLen(json_content) > 0)
    {
        ushort first_char = StringGetCharacter(json_content, 0);

        if (first_char != '{' && first_char != 123)
        {
            Print("AVISO: Arquivo não parece começar com '{' - ajustando...");

            // Tentar encontrar o primeiro '{'
            int brace_pos = StringFind(json_content, "{");
            if (brace_pos >= 0)
            {
                json_content = StringSubstr(json_content, brace_pos);
                Print("JSON ajustado, novo tamanho: ", StringLen(json_content));
            }
        }
        else
        {
            Print("Arquivo parece ser JSON válido");
        }
    }

    return LoadConfig(json_content);
}

//+------------------------------------------------------------------+
//| Criar contextos baseados na configuração                        |
//+------------------------------------------------------------------+
bool CConfigManager::CreateContexts()
{
    Print("=== CRIANDO CONTEXTOS ===");

    CJAVal *symbols_array = m_config["SYMBOLS"];
    if (symbols_array == NULL)
    {
        Print("ERRO: Array SYMBOLS não encontrado durante criação de contextos");
        return false;
    }

    // Percorrer cada objeto no array SYMBOLS
    for (int i = 0; i < symbols_array.Size(); i++)
    {
        CJAVal *symbol_obj = &symbols_array.children[i];

        // Cada objeto contém um símbolo como chave
        for (int j = 0; j < symbol_obj.Size(); j++)
        {
            string symbol = symbol_obj.children[j].key;
            CJAVal *symbol_config = &symbol_obj.children[j];

            Print("Processando símbolo: ", symbol);

            if (symbol_config == NULL)
            {
                Print("ERRO: Configuração não encontrada para símbolo: ", symbol);
                continue;
            }

            Print("Encontrados ", symbol_config.Size(), " timeframes para ", symbol);

            // Processar todos os timeframes do símbolo
            for (int t = 0; t < symbol_config.Size(); t++)
            {
                string tf_str = symbol_config.children[t].key;
                CJAVal *tf_config = &symbol_config.children[t];

                if (tf_config == NULL)
                {
                    Print("ERRO: Configuração de timeframe nula para ", tf_str);
                    continue;
                }

                // Converter string para enum de timeframe
                ENUM_TIMEFRAMES tf = ToTimeframe(tf_str);
                if (tf == PERIOD_CURRENT)
                {
                    Print("ERRO: TimeFrame inválido: ", tf_str);
                    continue;
                }

                // Usar o parser para processar a configuração do timeframe
                STimeframeConfig config;
                config = tf_ctx_parser.ParseTimeframeConfig(tf_config, tf);

                if (!config.enabled)
                {
                    Print("TimeFrame ", tf_str, " está desabilitado");
                    tf_ctx_parser.CleanupTimeframeConfig(config); // Cleanup added here
                    continue;
                }

                // Criar contexto usando o parser
                TF_CTX *ctx = tf_ctx_parser.CreateContext(symbol, tf, config);
                if (ctx == NULL)
                {
                    Print("ERRO: Falha ao criar contexto para ", symbol, " ", tf_str);
                    tf_ctx_parser.CleanupTimeframeConfig(config); // Cleanup added here
                    continue;
                }

                // Adicionar aos arrays de contextos
                string key = CreateContextKey(symbol, tf);
                ArrayResize(m_contexts, ArraySize(m_contexts) + 1);
                ArrayResize(m_context_keys, ArraySize(m_context_keys) + 1);

                m_contexts[ArraySize(m_contexts) - 1] = ctx;
                m_context_keys[ArraySize(m_context_keys) - 1] = key;

                Print("Contexto criado: ", key, " com ", ArraySize(config.indicators), " indicadores");
            }
        }
    }

    Print("=== CONTEXTOS CRIADOS ===");
    Print("Total de contextos ativos: ", ArraySize(m_contexts));
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

    string symbol_prefix = symbol + "_";

    for (int i = 0; i < ArraySize(m_context_keys); i++)
    {
        string key = m_context_keys[i];
        if (StringFind(key, symbol_prefix) == 0)
        {
            int pos = ArraySize(contexts);
            ArrayResize(contexts, pos + 1);
            ArrayResize(timeframes, pos + 1);

            contexts[pos] = m_contexts[i];

            string tf_str = StringSubstr(key, StringLen(symbol_prefix));
            timeframes[pos] = ToTimeframe(tf_str);
        }
    }

    return ArraySize(contexts);
}

//+------------------------------------------------------------------+
//| Limpar recursos                                                  |
//+------------------------------------------------------------------+
void CConfigManager::Cleanup()
{
    Print("Limpando recursos do ConfigManager...");

    // Deletar contextos de estratégia PRIMEIRO
    for (int i = ArraySize(m_strategy_contexts) - 1; i >= 0; i--)
    {
        if (m_strategy_contexts[i] != NULL)
        {
            delete m_strategy_contexts[i];
            m_strategy_contexts[i] = NULL;
        }
    }

    // Deletar contextos de indicadores
    for (int i = ArraySize(m_contexts) - 1; i >= 0; i--)
    {
        if (m_contexts[i] != NULL)
        {
            delete m_contexts[i];
            m_contexts[i] = NULL;
        }
    }

    ArrayResize(m_contexts, 0);
    ArrayResize(m_context_keys, 0);
    ArrayResize(m_strategy_contexts, 0);
    ArrayResize(m_strategy_keys, 0);
    ArrayResize(m_symbols, 0);
    m_config.Clear();
    m_initialized = false;

    Print("Recursos limpos com sucesso");
}

//+------------------------------------------------------------------+
//| Teste básico de JSON parsing                                    |
//+------------------------------------------------------------------+
bool CConfigManager::TestJSONParsing()
{
    string test_json = "{\"test_key\":\"test_value\"}";
    CJAVal test_config;

    bool result = test_config.Deserialize(test_json);
    if (result)
    {
        Print("Teste básico de JSON: SUCESSO");
        string test_value = test_config["test_key"].ToStr();
        Print("Valor teste recuperado: ", test_value);
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
    case PERIOD_M1:
        return "M1";
    case PERIOD_M3:
        return "M3";
    case PERIOD_M5:
        return "M5";
    case PERIOD_M15:
        return "M15";
    case PERIOD_M30:
        return "M30";
    case PERIOD_H1:
        return "H1";
    case PERIOD_H4:
        return "H4";
    case PERIOD_D1:
        return "D1";
    case PERIOD_W1:
        return "W1";
    case PERIOD_MN1:
        return "MN1";
    default:
        return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Criar chave do contexto                                         |
//+------------------------------------------------------------------+
string CConfigManager::CreateContextKey(string symbol, ENUM_TIMEFRAMES tf)
{
    return symbol + "_" + TimeframeToString(tf);
}

//+------------------------------------------------------------------+
//| Abrir arquivo de configuração com diferentes tentativas         |
//+------------------------------------------------------------------+
int CConfigManager::OpenConfigFile(string file_path)
{
    Print("Tentando abrir arquivo: ", file_path);

    // Primeira tentativa: pasta local do EA (ANSI)
    int handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_ANSI);
    if (handle != INVALID_HANDLE)
    {
        Print("Arquivo encontrado na pasta local do EA (ANSI)");
        return handle;
    }

    // Segunda tentativa: pasta Common (ANSI)
    Print("Tentando pasta Common (ANSI)...");
    handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);
    if (handle != INVALID_HANDLE)
    {
        Print("Arquivo encontrado na pasta Common (ANSI)");
        return handle;
    }

    // Terceira tentativa: pasta Common (UTF-8)
    Print("Tentando pasta Common (UTF-8)...");
    handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON);
    if (handle != INVALID_HANDLE)
    {
        Print("Arquivo encontrado na pasta Common (UTF-8)");
        return handle;
    }

    // Arquivo não encontrado
    Print("ERRO: Arquivo não encontrado em nenhuma localização");
    Print("Verificar se o arquivo existe em:");
    Print("1. Terminal_Data_Folder\\MQL5\\Files\\", file_path);
    Print("2. Common_Data_Folder\\Files\\", file_path);

    return 0;
}

//+------------------------------------------------------------------+
//| STRATEGY_CTX RELATED METHODS                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Criar contextos de estratégia baseados na configuração          |
//+------------------------------------------------------------------+
bool CConfigManager::CreateStrategyContexts()
{
    Print("=== CRIANDO CONTEXTOS DE ESTRATÉGIA ===");

    CJAVal *strategies_array = m_config["STRATEGIES"];
    if (strategies_array == NULL)
    {
        Print("AVISO: Array STRATEGIES não encontrado - nenhuma estratégia configurada");
        return true; // Não é erro, apenas não há estratégias
    }

    // Percorrer cada objeto no array STRATEGIES
    for (int i = 0; i < strategies_array.Size(); i++)
    {
        CJAVal *strategy_obj = &strategies_array.children[i];
        
        // Cada objeto contém um setup como chave
        for (int j = 0; j < strategy_obj.Size(); j++)
        {
            string setup_name = strategy_obj.children[j].key;
            CJAVal *setup_config = &strategy_obj.children[j];
            
            Print("Processando setup: ", setup_name);

            if (setup_config == NULL)
            {
                Print("ERRO: Configuração não encontrada para setup: ", setup_name);
                continue;
            }

            // Verificar se o setup está habilitado
            if (!setup_config["enabled"].ToBool())
            {
                Print("Setup ", setup_name, " está desabilitado");
                continue;
            }

            // Obter array de estratégias
            CJAVal *strategies_list = setup_config["strategies"];
            if (strategies_list == NULL)
            {
                Print("ERRO: Lista de estratégias não encontrada para setup: ", setup_name);
                continue;
            }

            // Usar o parser para processar as estratégias do setup
            SStrategySetupConfig setup_cfg;
            setup_cfg = strategy_ctx_parser.ParseStrategySetup(setup_config);

            if (!setup_cfg.enabled)
            {
                Print("Setup ", setup_name, " está desabilitado no parser");
                strategy_ctx_parser.CleanupStrategySetup(setup_cfg);
                continue;
            }

            // Criar contexto usando o parser
            STRATEGY_CTX *ctx = strategy_ctx_parser.CreateStrategyContext(setup_name, setup_cfg);
            if (ctx == NULL)
            {
                Print("ERRO: Falha ao criar contexto de estratégia para ", setup_name);
                strategy_ctx_parser.CleanupStrategySetup(setup_cfg);
                continue;
            }

            // Definir o config_manager no contexto de estratégia
            ctx.SetConfigManager(&this);

            // Adicionar aos arrays de contextos de estratégia
            string key = CreateStrategyKey(setup_name);
            ArrayResize(m_strategy_contexts, ArraySize(m_strategy_contexts) + 1);
            ArrayResize(m_strategy_keys, ArraySize(m_strategy_keys) + 1);

            m_strategy_contexts[ArraySize(m_strategy_contexts) - 1] = ctx;
            m_strategy_keys[ArraySize(m_strategy_keys) - 1] = key;

            Print("Contexto de estratégia criado: ", key, " com ", ArraySize(setup_cfg.strategies), " estratégias");
        }
    }

    Print("=== CONTEXTOS DE ESTRATÉGIA CRIADOS ===");
    Print("Total de contextos de estratégia ativos: ", ArraySize(m_strategy_contexts));
    return true;
}

//+------------------------------------------------------------------+
//| Criar chave do contexto de estratégia                           |
//+------------------------------------------------------------------+
string CConfigManager::CreateStrategyKey(string setup_name)
{
    return setup_name;
}

//+------------------------------------------------------------------+
//| Obter contexto de estratégia por nome do setup                  |
//+------------------------------------------------------------------+
STRATEGY_CTX *CConfigManager::GetStrategyContext(string setup_name)
{
    string key = CreateStrategyKey(setup_name);

    for (int i = 0; i < ArraySize(m_strategy_keys); i++)
    {
        if (m_strategy_keys[i] == key)
        {
            return m_strategy_contexts[i];
        }
    }

    return NULL;
}

//+------------------------------------------------------------------+
//| Verificar se setup de estratégia está habilitado                |
//+------------------------------------------------------------------+
bool CConfigManager::IsStrategySetupEnabled(string setup_name)
{
    return GetStrategyContext(setup_name) != NULL;
}

//+------------------------------------------------------------------+
//| Obter setups de estratégia configurados                         |
//+------------------------------------------------------------------+
void CConfigManager::GetConfiguredStrategySetups(string &setups[])
{
    ArrayResize(setups, 0);
    
    for (int i = 0; i < ArraySize(m_strategy_keys); i++)
    {
        ArrayResize(setups, ArraySize(setups) + 1);
        setups[ArraySize(setups) - 1] = m_strategy_keys[i];
    }
}

//+------------------------------------------------------------------+
//| Obter todos os contextos de estratégia                          |
//+------------------------------------------------------------------+
int CConfigManager::GetStrategyContexts(STRATEGY_CTX *&contexts[], string &setup_names[])
{
    ArrayResize(contexts, ArraySize(m_strategy_contexts));
    ArrayResize(setup_names, ArraySize(m_strategy_keys));

    for (int i = 0; i < ArraySize(m_strategy_contexts); i++)
    {
        contexts[i] = m_strategy_contexts[i];
        setup_names[i] = m_strategy_keys[i];
    }

    return ArraySize(contexts);
}