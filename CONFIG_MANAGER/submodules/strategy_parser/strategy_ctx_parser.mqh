//+------------------------------------------------------------------+
//|                                           strategy_ctx_parser.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include "../../../utils/common_types.mqh"
#include "../../../interfaces/icontext_provider.mqh"
#include "../../../STRATEGIES/strategy_ctx.mqh"
#include "../../../STRATEGIES/strategies/strategies_types.mqh"
#include "../../config_types.mqh"

//+------------------------------------------------------------------+
//| Estrutura para configuração de setup de estratégia              |
//+------------------------------------------------------------------+
struct SStrategySetupConfig
{
    bool enabled;
    string setup_name;
    CStrategyConfig *strategies[];
};

//+------------------------------------------------------------------+
//| Parser para contextos de estratégia                             |
//+------------------------------------------------------------------+
class CStrategyConfigParser
{
public:
    SStrategySetupConfig ParseStrategySetup(CJAVal *setup_config);
    STRATEGY_CTX *CreateStrategyContext(string setup_name, SStrategySetupConfig &config, IContextProvider *context_provider);
    void CleanupStrategySetup(SStrategySetupConfig &config);

private:
    CStrategyConfig *ParseSingleStrategy(CJAVal *strategy_json);
    CEmasBullBuyConfig *ParseEmasBuyBullConfig(CJAVal *strategy_json);
};

//+------------------------------------------------------------------+
//| Parsear configuração de setup de estratégia                     |
//+------------------------------------------------------------------+
SStrategySetupConfig CStrategyConfigParser::ParseStrategySetup(CJAVal *setup_config)
{
    SStrategySetupConfig config;
    config.enabled = false;
    ArrayResize(config.strategies, 0);

    if (setup_config == NULL)
    {
        Print("ERRO: Configuração de setup nula");
        return config;
    }

    // Verificar se está habilitado
    config.enabled = setup_config["enabled"].ToBool();
    if (!config.enabled)
    {
        Print("Setup desabilitado");
        return config;
    }

    // Obter array de estratégias
    CJAVal *strategies_array = setup_config["strategies"];
    if (strategies_array == NULL)
    {
        Print("ERRO: Array de estratégias não encontrado");
        config.enabled = false;
        return config;
    }

    Print("Parseando ", strategies_array.Size(), " estratégias...");

    // Parsear cada estratégia
    for (int i = 0; i < strategies_array.Size(); i++)
    {
        CJAVal *strategy_json = &strategies_array.children[i];
        if (strategy_json == NULL)
            continue;

        CStrategyConfig *strategy_cfg = ParseSingleStrategy(strategy_json);
        if (strategy_cfg == NULL)
        {
            Print("ERRO: Falha ao parsear estratégia ", i);
            continue;
        }

        // Adicionar ao array
        int pos = ArraySize(config.strategies);
        ArrayResize(config.strategies, pos + 1);
        config.strategies[pos] = strategy_cfg;

        Print("Estratégia parseada: ", strategy_cfg.name, " (", strategy_cfg.type, ")");
    }

    Print("Setup parseado com sucesso: ", ArraySize(config.strategies), " estratégias");
    return config;
}

//+------------------------------------------------------------------+
//| Parsear uma única estratégia                                    |
//+------------------------------------------------------------------+
CStrategyConfig *CStrategyConfigParser::ParseSingleStrategy(CJAVal *strategy_json)
{
    if (strategy_json == NULL)
        return NULL;

    string strategy_type = strategy_json["type"].ToStr();
    string strategy_name = strategy_json["name"].ToStr();
    bool enabled = strategy_json["enabled"].ToBool();

    if (!enabled)
    {
        Print("Estratégia ", strategy_name, " está desabilitada");
        return NULL;
    }

    if (StringLen(strategy_type) == 0)
    {
        Print("ERRO: Tipo de estratégia vazio para ", strategy_name);
        return NULL;
    }

    // Criar configuração baseada no tipo
    if (strategy_type == "emas_buy_bull")
    {
        return ParseEmasBuyBullConfig(strategy_json);
    }
    // Adicionar outros tipos conforme necessário
    // else if (strategy_type == "emas_sell_bear")
    // {
    //     return ParseEmasSellBearConfig(strategy_json);
    // }

    Print("ERRO: Tipo de estratégia não suportado: ", strategy_type);
    return NULL;
}

//+------------------------------------------------------------------+
//| Parsear configuração EMA Buy Bull                               |
//+------------------------------------------------------------------+
CEmasBullBuyConfig *CStrategyConfigParser::ParseEmasBuyBullConfig(CJAVal *strategy_json)
{
    CEmasBullBuyConfig *config = new CEmasBullBuyConfig();
    if (config == NULL)
        return NULL;

    // Configurações básicas
    config.name = strategy_json["name"].ToStr();
    config.type = strategy_json["type"].ToStr();
    config.enabled = strategy_json["enabled"].ToBool();

    // Configurações específicas da estratégia EMA Buy Bull
    config.risk_percent = strategy_json["risk_percent"].ToDbl();
    config.stop_loss_pips = strategy_json["stop_loss_pips"].ToDbl();
    config.take_profit_ratio = strategy_json["take_profit_ratio"].ToDbl();

    // New configurable parameters
    config.min_distance_9_21_atr = strategy_json["min_distance_9_21_atr"].ToDbl();
    config.min_distance_21_50_atr = strategy_json["min_distance_21_50_atr"].ToDbl();
    config.lookback_candles = (int)(long)strategy_json["lookback_candles"].ToDbl();
    config.max_distance_atr = strategy_json["max_distance_atr"].ToDbl();
    config.max_duration_candles = (int)(long)strategy_json["max_duration_candles"].ToDbl();
    config.lookback_periods = (int)(long)strategy_json["lookback_periods"].ToDbl();
    config.min_volatility_ratio = strategy_json["min_volatility_ratio"].ToDbl();
    config.max_volatility_ratio = strategy_json["max_volatility_ratio"].ToDbl();
    config.bullish_structure_atr_threshold = strategy_json["bullish_structure_atr_threshold"].ToDbl();
    config.adx_min_value = (int)(long)strategy_json["adx_min_value"].ToDbl();
    config.adx_max_value = (int)(long)strategy_json["adx_max_value"].ToDbl();

    Print("EMA Buy Bull config parseada: ", config.name);
    return config;
}

//+------------------------------------------------------------------+
//| Criar contexto de estratégia                                    |
//+------------------------------------------------------------------+
STRATEGY_CTX *CStrategyConfigParser::CreateStrategyContext(string setup_name, SStrategySetupConfig &config, IContextProvider *context_provider)
{
    if (!config.enabled || ArraySize(config.strategies) == 0)
    {
        Print("ERRO: Setup desabilitado ou sem estratégias");
        return NULL;
    }

    // Criar array de configurações para o construtor
    CStrategyConfig *cfg_array[];
    ArrayResize(cfg_array, ArraySize(config.strategies));
    
    for (int i = 0; i < ArraySize(config.strategies); i++)
    {
        cfg_array[i] = config.strategies[i];
    }

    // Criar contexto
    STRATEGY_CTX *ctx = new STRATEGY_CTX(setup_name, cfg_array, context_provider);
    if (ctx == NULL)
    {
        Print("ERRO: Falha ao criar STRATEGY_CTX");
        return NULL;
    }

    // Inicializar contexto
    if (!ctx.Init())
    {
        Print("ERRO: Falha ao inicializar STRATEGY_CTX");
        delete ctx;
        return NULL;
    }

    Print("Contexto de estratégia criado com sucesso: ", setup_name);
    return ctx;
}

//+------------------------------------------------------------------+
//| Limpar configuração de setup                                    |
//+------------------------------------------------------------------+
void CStrategyConfigParser::CleanupStrategySetup(SStrategySetupConfig &config)
{
    // Limpar apenas se as configurações não foram transferidas para o contexto
    // O contexto assume a propriedade das configurações após a criação
    for (int i = 0; i < ArraySize(config.strategies); i++)
    {
        if (config.strategies[i] != NULL)
        {
            delete config.strategies[i];
            config.strategies[i] = NULL;
        }
    }
    ArrayResize(config.strategies, 0);
    config.enabled = false;
}