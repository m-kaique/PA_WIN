//+------------------------------------------------------------------+
//|                                           config_manager.mqh     |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include  "submodules/tf_ctx_parser/tf_ctx_parser.mqh"
#include "../utils/JAson.mqh"
#include "../utils/conversion.mqh"
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

    // Extrair símbolos da configuração
    ArrayResize(m_symbols, 0);
    for (int i = 0; i < m_config.Size(); i++)
    {
        string symbol = m_config.children[i].key;
        if (StringLen(symbol) > 0)
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

        Print("Encontrados ", symbol_config.Size(), " timeframes para ", symbol);

        // Processar todos os timeframes do símbolo
        for (int t = 0; t < symbol_config.Size(); t++)
        {
            string tf_str = symbol_config.children[t].key;
            CJAVal *tf_config = symbol_config[tf_str];

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
                continue;
            }

            // Criar contexto usando o parser
            TF_CTX *ctx = tf_ctx_parser.CreateContext(symbol, tf, config);
            if (ctx == NULL)
            {
                Print("ERRO: Falha ao criar contexto para ", symbol, " ", tf_str);
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
    
    // Deletar contextos
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
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default: return "UNKNOWN";
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