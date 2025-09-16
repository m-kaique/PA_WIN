//+------------------------------------------------------------------+
//|                                    timeframe_config_parser.mqh  |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include "../../../utils/common_types.mqh"
#include "../../../TF_CTX/tf_ctx.mqh"
#include "../../config_types.mqh"

//+------------------------------------------------------------------+
//| Classe para parsing de configurações de timeframe               |
//+------------------------------------------------------------------+
class CTimeframeConfigParser
{
private:
    // Métodos de conversão de string para enums
    ENUM_TIMEFRAMES StringToTimeframe(string tf_str);
    ENUM_MA_METHOD StringToMAMethod(string method_str);
    ENUM_STO_PRICE StringToPriceField(string field_str);
    ENUM_APPLIED_PRICE StringToAppliedPrice(string price_str);
    ENUM_VWAP_CALC_MODE StringToVWAPCalcMode(string mode_str);
    ENUM_VWAP_PRICE_TYPE StringToVWAPPriceType(string type_str);
    ENUM_LINE_STYLE StringToLineStyle(string style_str);
    color StringToColor(string color_str);

    // Métodos para criar configurações específicas de indicadores
    void FillIndicatorBase(CIndicatorConfig &cfg, CJAVal *node, string type);
    CIndicatorConfig *CreateIndicatorConfig(CJAVal *ind);

    // Métodos específicos para cada tipo de indicador
    CMAConfig *CreateMAConfig(CJAVal *ind);
    CStochasticConfig *CreateStochasticConfig(CJAVal *ind);
    CVolumeConfig *CreateVolumeConfig(CJAVal *ind);
    CAdxConfig *CreateAdxConfig(CJAVal *ind);
    CAtrConfig *CreateAtrConfig(CJAVal *ind);
    CVWAPConfig *CreateVWAPConfig(CJAVal *ind);
    CBollingerConfig *CreateBollingerConfig(CJAVal *ind);
    CFiboConfig *CreateFiboConfig(CJAVal *ind);
    CTrendLineConfig *CreateTrendLineConfig(CJAVal *ind);
    CSupResConfig *CreateSupResConfig(CJAVal *ind);

public:
    // Construtor
    CTimeframeConfigParser();
    ~CTimeframeConfigParser();

    // Método principal para parsing de configuração de timeframe
    STimeframeConfig ParseTimeframeConfig(CJAVal *tf_config, ENUM_TIMEFRAMES ctx_tf);

    // Método para criar contexto baseado na configuração
    TF_CTX *CreateContext(string symbol, ENUM_TIMEFRAMES timeframe, STimeframeConfig &config);

    //+------------------------------------------------------------------+
    //| Cleanup das configurações                                        |
    //+------------------------------------------------------------------+
    void CleanupTimeframeConfig(STimeframeConfig &config)
    {
        // Libera memória dos indicadores
        int ind_count = ArraySize(config.indicators);
        for (int i = 0; i < ind_count; i++)
        {
            if (config.indicators[i] != NULL)
            {
                Print("Deletando " + config.indicators[i].name);
                delete config.indicators[i];
                config.indicators[i] = NULL;
            }
        }
        ArrayResize(config.indicators, 0);

        // Resetar os campos básicos
        config.enabled = false;
        config.num_candles = 0;
    }

    //+------------------------------------------------------------------+
    //| Cleanup do contexto                                              |
    //+------------------------------------------------------------------+
    static void CleanupContext(TF_CTX *&ctx)
    {
        if (ctx != NULL)
        {
            delete ctx;
            ctx = NULL;
        }
    }
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CTimeframeConfigParser::CTimeframeConfigParser()
{
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CTimeframeConfigParser::~CTimeframeConfigParser()
{
}

//+------------------------------------------------------------------+
//| Fazer parse da configuração do timeframe                        |
//+------------------------------------------------------------------+
STimeframeConfig CTimeframeConfigParser::ParseTimeframeConfig(CJAVal *tf_config, ENUM_TIMEFRAMES ctx_tf)
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
    ArrayResize(config.indicators, 0);

    if (ind_array != NULL)
    {
        Print("Processando ", ind_array.Size(), " indicadores");

        for (int i = 0; i < ind_array.Size(); i++)
        {
            CIndicatorConfig *icfg = CreateIndicatorConfig((*ind_array)[i]);
            if (icfg == NULL)
            {
                Print("AVISO: Falha ao criar configuração do indicador ", i);
                continue;
            }

            int pos = ArraySize(config.indicators);
            ArrayResize(config.indicators, pos + 1);
            config.indicators[pos] = icfg;

            Print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
            Print("Indicador lido: ", icfg.name, " Tipo: ", icfg.type, " Enabled: ", icfg.enabled);
            Print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        }
    }
    else
    {
        Print("AVISO: Nenhum indicador configurado para este timeframe");
    }

    Print("Total de indicadores carregados: ", ArraySize(config.indicators));
    return config;
}

//+------------------------------------------------------------------+
//| Criar contexto baseado na configuração                          |
//+------------------------------------------------------------------+
TF_CTX *CTimeframeConfigParser::CreateContext(string symbol, ENUM_TIMEFRAMES timeframe, STimeframeConfig &config)
{
    if (!config.enabled)
    {
        Print("Contexto desabilitado para ", symbol, " ", EnumToString(timeframe));
        return NULL;
    }

    Print("Criando contexto para ", symbol, " ", EnumToString(timeframe),
          " com ", ArraySize(config.indicators), " indicadores");

    TF_CTX *ctx = new TF_CTX(timeframe, config.num_candles,
                             config.indicators);

    if (ctx == NULL)
    {
        Print("ERRO: Falha ao alocar memória para contexto");
        return NULL;
    }

    if (!ctx.Init())
    {
        Print("ERRO: Falha ao inicializar contexto");
        delete ctx;
        return NULL;
    }

    Print("Contexto criado com sucesso para ", symbol, " ", EnumToString(timeframe));
    return ctx;
}

//+------------------------------------------------------------------+
//| Preencher campos básicos de um indicador                        |
//+------------------------------------------------------------------+
void CTimeframeConfigParser::FillIndicatorBase(CIndicatorConfig &cfg, CJAVal *node, string type)
{
    cfg.name = (*node)["name"].ToStr();
    cfg.type = type;
    cfg.enabled = (*node)["enabled"].ToBool();
    cfg.attach_chart = (*node)["attach_chart"].ToBool();
    cfg.alert_tf = StringToTimeframe((*node)["alert_tf"].ToStr());

    // Ler slope_values se existir no JSON
    if ((*node).HasKey("slope_values"))
    {
        CJAVal *slope_values_array_node = (*node)["slope_values"];

        int num_slopes = slope_values_array_node.Size();
        ArrayResize(cfg.slope_values, num_slopes);

        Print("Carregando ", num_slopes, " configurações de slope para indicador ", cfg.name);

        for (int i = 0; i < num_slopes; i++)
        {
            CJAVal *slope_node = slope_values_array_node[i];
            if (slope_node.HasKey("lookback"))
                cfg.slope_values[i].lookback = (int)slope_node["lookback"].ToInt();
            if (slope_node.HasKey("simple_diff"))
                cfg.slope_values[i].simple_diff = slope_node["simple_diff"].ToDbl();
            if (slope_node.HasKey("linear_reg"))
                cfg.slope_values[i].linear_reg = slope_node["linear_reg"].ToDbl();
            if (slope_node.HasKey("discrete_der"))
                cfg.slope_values[i].discrete_der = slope_node["discrete_der"].ToDbl();
        }
    }
}

//+------------------------------------------------------------------+
//| Criar configuração de indicador genérico                        |
//+------------------------------------------------------------------+
CIndicatorConfig *CTimeframeConfigParser::CreateIndicatorConfig(CJAVal *ind)
{
    if (ind == NULL)
    {
        Print("ERRO: Nó de indicador é NULL");
        return NULL;
    }

    string type = ind["type"].ToStr();
    Print("Criando configuração para indicador tipo: ", type);

    if (type == "MA")
        return CreateMAConfig(ind);
    else if (type == "STO")
        return CreateStochasticConfig(ind);
    else if (type == "VOL")
        return CreateVolumeConfig(ind);
    else if (type == "ADX")
        return CreateAdxConfig(ind);
    else if (type == "ATR")
        return CreateAtrConfig(ind);
    else if (type == "VWAP")
        return CreateVWAPConfig(ind);
    else if (type == "BOLL")
        return CreateBollingerConfig(ind);
    else if (type == "FIBO")
        return CreateFiboConfig(ind);
    else if (type == "TRENDLINE")
        return CreateTrendLineConfig(ind);
    else if (type == "SUPRES")
        return CreateSupResConfig(ind);
    else
    {
        Print("ERRO: Tipo de indicador não reconhecido: ", type);
        return NULL;
    }
}

//+------------------------------------------------------------------+
//| Criar configuração de Média Móvel                               |
//+------------------------------------------------------------------+
CMAConfig *CTimeframeConfigParser::CreateMAConfig(CJAVal *ind)
{
    CMAConfig *p = new CMAConfig();
    FillIndicatorBase(*p, ind, "MA");
    p.period = (int)ind["period"].ToInt();
    p.method = StringToMAMethod(ind["method"].ToStr());
    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de Estocástico                               |
//+------------------------------------------------------------------+
CStochasticConfig *CTimeframeConfigParser::CreateStochasticConfig(CJAVal *ind)
{
    CStochasticConfig *p = new CStochasticConfig();
    FillIndicatorBase(*p, ind, "STO");
    p.period = (int)ind["period"].ToInt();
    p.dperiod = (int)ind["dperiod"].ToInt();
    p.slowing = (int)ind["slowing"].ToInt();
    p.method = StringToMAMethod(ind["method"].ToStr());
    p.price_field = StringToPriceField(ind["price_field"].ToStr());
    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de Volume                                    |
//+------------------------------------------------------------------+
CVolumeConfig *CTimeframeConfigParser::CreateVolumeConfig(CJAVal *ind)
{
    CVolumeConfig *p = new CVolumeConfig();
    FillIndicatorBase(*p, ind, "VOL");
    p.shift = (int)ind["shift"].ToInt();
    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de ADX                                       |
//+------------------------------------------------------------------+
CAdxConfig *CTimeframeConfigParser::CreateAdxConfig(CJAVal *ind)
{
    CAdxConfig *p = new CAdxConfig();
    FillIndicatorBase(*p, ind, "ADX");
    p.period = (int)ind["period"].ToInt();
    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de ATR                                       |
//+------------------------------------------------------------------+
CAtrConfig *CTimeframeConfigParser::CreateAtrConfig(CJAVal *ind)
{
    CAtrConfig *p = new CAtrConfig();
    FillIndicatorBase(*p, ind, "ATR");
    p.period = (int)ind["period"].ToInt();
    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de VWAP                                      |
//+------------------------------------------------------------------+
CVWAPConfig *CTimeframeConfigParser::CreateVWAPConfig(CJAVal *ind)
{
    CVWAPConfig *p = new CVWAPConfig();
    FillIndicatorBase(*p, ind, "VWAP");
    p.period = (int)ind["period"].ToInt();
    p.method = StringToMAMethod(ind["method"].ToStr());
    p.calc_mode = StringToVWAPCalcMode(ind["calc_mode"].ToStr());
    p.session_tf = StringToTimeframe(ind["session_tf"].ToStr());
    p.price_type = StringToVWAPPriceType(ind["price_type"].ToStr());

    string start_str = ind["start_time"].ToStr();
    if (StringLen(start_str) > 0)
        p.start_time = StringToTime(start_str);

    p.line_color = StringToColor(ind["Color"].ToStr());
    p.line_style = StringToLineStyle(ind["Style"].ToStr());
    p.line_width = (int)ind["Width"].ToInt();
    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de Bandas de Bollinger                       |
//+------------------------------------------------------------------+
CBollingerConfig *CTimeframeConfigParser::CreateBollingerConfig(CJAVal *ind)
{
    CBollingerConfig *p = new CBollingerConfig();
    FillIndicatorBase(*p, ind, "BOLL");
    p.period = (int)ind["period"].ToInt();
    p.shift = (int)ind["shift"].ToInt();
    p.deviation = ind["deviation"].ToDbl();
    p.applied_price = StringToAppliedPrice(ind["applied_price"].ToStr());
    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de Fibonacci                                 |
//+------------------------------------------------------------------+
CFiboConfig *CTimeframeConfigParser::CreateFiboConfig(CJAVal *ind)
{
    CFiboConfig *p = new CFiboConfig();
    FillIndicatorBase(*p, ind, "FIBO");
    p.period = (int)ind["period"].ToInt();

    // Níveis de retração
    p.level_1 = ind["Level_1"].ToDbl();
    p.level_2 = ind["Level_2"].ToDbl();
    p.level_3 = ind["Level_3"].ToDbl();
    p.level_4 = ind["Level_4"].ToDbl();
    p.level_5 = ind["Level_5"].ToDbl();
    p.level_6 = ind["Level_6"].ToDbl();

    p.levels_color = StringToColor(ind["LevelsColor"].ToStr());
    p.levels_style = StringToLineStyle(ind["LevelsStyle"].ToStr());
    p.levels_width = (int)ind["LevelsWidth"].ToInt();

    // Extensões
    p.ext_1 = ind["Ext_1"].ToDbl();
    p.ext_2 = ind["Ext_2"].ToDbl();
    p.ext_3 = ind["Ext_3"].ToDbl();

    p.extensions_color = StringToColor(ind["ExtensionsColor"].ToStr());
    p.extensions_style = StringToLineStyle(ind["ExtensionsStyle"].ToStr());
    p.extensions_width = (int)ind["ExtensionsWidth"].ToInt();

    // Linhas paralelas
    p.parallel_color = StringToColor(ind["ParallelColor"].ToStr());
    p.parallel_style = StringToLineStyle(ind["ParallelStyle"].ToStr());
    p.parallel_width = (int)ind["ParallelWidth"].ToInt();

    // Labels
    p.show_labels = ind["ShowLabels"].ToBool();
    p.labels_color = StringToColor(ind["LabelsColor"].ToStr());
    p.labels_font_size = (int)ind["LabelsFontSize"].ToInt();

    string font = ind["LabelsFont"].ToStr();
    if (StringLen(font) > 0)
        p.labels_font = font;

    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de Linha de Tendência                        |
//+------------------------------------------------------------------+
CTrendLineConfig *CTimeframeConfigParser::CreateTrendLineConfig(CJAVal *ind)
{
    CTrendLineConfig *p = new CTrendLineConfig();
    FillIndicatorBase(*p, ind, "TRENDLINE");

    p.period = (int)ind["period"].ToInt();
    p.pivot_left = (int)ind["pivot_left"].ToInt();
    p.pivot_right = (int)ind["pivot_right"].ToInt();

    // Configurações de desenho
    p.draw_lta = ind["draw_lta"].ToBool();
    p.draw_ltb = ind["draw_ltb"].ToBool();
    p.lta_color = StringToColor(ind["lta_color"].ToStr());
    p.ltb_color = StringToColor(ind["ltb_color"].ToStr());
    p.lta_style = StringToLineStyle(ind["lta_style"].ToStr());
    p.ltb_style = StringToLineStyle(ind["ltb_style"].ToStr());
    p.lta_width = (int)ind["lta_width"].ToInt();
    p.ltb_width = (int)ind["ltb_width"].ToInt();
    p.extend_right = ind["extend_right"].ToBool();
    p.min_angle = ind["min_angle"].ToDbl();

    // Configurações específicas de trend line
    p.candles_lookback = (int)ind["trendline_candles_lookback"].ToInt();

    // Status flags
    CJAVal *flags = ind["trendline_status_flags"];
    if (flags != NULL)
    {
        p.status_flags.enable_body_cross = flags["enable_body_cross"].ToBool();
        p.status_flags.enable_between_ltas = flags["enable_between_ltas"].ToBool();
        p.status_flags.enable_between_ltbs = flags["enable_between_ltbs"].ToBool();
        p.status_flags.enable_distance_points = flags["enable_distance_points"].ToBool();
    }

    // Context analysis
    CJAVal *ctx = ind["trendline_context_analysis"];
    if (ctx != NULL)
    {
        p.context_analysis.enabled = ctx["enabled"].ToBool();
        p.context_analysis.lookback = (int)ctx["lookback"].ToInt();
        p.context_analysis.trend_threshold = ctx["trend_threshold"].ToDbl();
        p.context_analysis.consolidation_threshold = ctx["consolidation_threshold"].ToDbl();
    }

    // Advanced features
    CJAVal *adv = ind["trendline_advanced_features"];
    if (adv != NULL)
    {
        p.advanced_features.detect_fakeout = adv["detect_fakeout"].ToBool();
        p.advanced_features.count_touches = adv["count_touches"].ToBool();
        p.advanced_features.touch_tolerance_points = adv["touch_tolerance_points"].ToDbl();

        string mode = adv["status_evaluate_mode"].ToStr();
        if (StringLen(mode) > 0)
            p.advanced_features.status_evaluate_mode = mode;

        p.advanced_features.register_resets = adv["register_resets"].ToBool();
    }

    return p;
}

//+------------------------------------------------------------------+
//| Criar configuração de Suporte e Resistência                     |
//+------------------------------------------------------------------+
CSupResConfig *CTimeframeConfigParser::CreateSupResConfig(CJAVal *ind)
{
    CSupResConfig *p = new CSupResConfig();
    FillIndicatorBase(*p, ind, "SUPRES");

    p.period = (int)ind["period"].ToInt();

    // Configurações de desenho
    p.draw_sup = ind["draw_sup"].ToBool();
    p.draw_res = ind["draw_res"].ToBool();
    p.sup_color = StringToColor(ind["sup_color"].ToStr());
    p.res_color = StringToColor(ind["res_color"].ToStr());
    p.sup_style = StringToLineStyle(ind["sup_style"].ToStr());
    p.res_style = StringToLineStyle(ind["res_style"].ToStr());
    p.sup_width = (int)ind["sup_width"].ToInt();
    p.res_width = (int)ind["res_width"].ToInt();
    p.extend_right = ind["extend_right"].ToBool();
    p.show_labels = ind["show_labels"].ToBool();

    // Configurações de análise
    p.touch_lookback = (int)ind["touch_lookback"].ToInt();
    p.touch_tolerance = ind["touch_tolerance"].ToDbl();
    p.zone_range = ind["zone_range"].ToDbl();
    p.max_zones_to_draw = (int)ind["max_zones_to_draw"].ToInt();
    p.min_touches = (int)ind["min_touches"].ToInt();
    p.validation = (ENUM_SUPRES_VALIDATION)ind["validation"].ToInt();

    return p;
}

//+------------------------------------------------------------------+
//| Métodos de conversão string para enum                           |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES CTimeframeConfigParser::StringToTimeframe(string tf_str)
{
    return ToTimeframe(tf_str);
}

ENUM_MA_METHOD CTimeframeConfigParser::StringToMAMethod(string method_str)
{
    return ToMaMethod(method_str);
}

ENUM_STO_PRICE CTimeframeConfigParser::StringToPriceField(string field_str)
{
    return ToPriceField(field_str);
}

ENUM_APPLIED_PRICE CTimeframeConfigParser::StringToAppliedPrice(string price_str)
{
    return ToAppliedPrice(price_str);
}

ENUM_VWAP_CALC_MODE CTimeframeConfigParser::StringToVWAPCalcMode(string mode_str)
{
    return ToVWAPCalcMode(mode_str);
}

ENUM_VWAP_PRICE_TYPE CTimeframeConfigParser::StringToVWAPPriceType(string type_str)
{
    return ToVWAPPriceType(type_str);
}

ENUM_LINE_STYLE CTimeframeConfigParser::StringToLineStyle(string style_str)
{
    return ToLineStyle(style_str);
}

color CTimeframeConfigParser::StringToColor(string color_str)
{
    return ToColor(color_str);
}