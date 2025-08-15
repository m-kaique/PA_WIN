//+------------------------------------------------------------------+
//|                                    indicators/moving_averages.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.02"
#include "../indicator_base/indicator_base.mqh"
#include "../../config_types.mqh"
#include "ma_defs.mqh"

//+------------------------------------------------------------------+
//| Classe para cálculo de médias móveis                            |
//+------------------------------------------------------------------+
class CMovingAverages : public CIndicatorBase
{
private:
    int m_period;                // Período para cálculo das médias
    ENUM_MA_METHOD m_method;     // Método da média móvel

    // Métodos privados
    bool CreateIndicatorHandles();
    void ReleaseIndicatorHandles();
    double GetIndicatorValue(int handle, int shift = 0);

    

public:
    // Construtor
    CMovingAverages();

    // Destrutor
    ~CMovingAverages();

    // Inicialização
    bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method);
    bool Init(string symbol, ENUM_TIMEFRAMES timeframe, CMAConfig &config);

    // Método para obter valor da média móvel
    double GetValue(int shift = 0);

    // Obter múltiplos valores da média móvel
    bool CopyValues(int shift, int count, double &buffer[]);

    // Verificar se os indicadores estão prontos
    bool IsReady();

    // Atualizar estado interno (recriar handle se necessario)
    virtual bool Update() override;


};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CMovingAverages::CMovingAverages()
{
    m_symbol = "";
    m_timeframe = PERIOD_CURRENT;
    m_period = 0;
    m_method = MODE_SMA;

    // Inicializar handle como inválido
    handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CMovingAverages::~CMovingAverages()
{
    ReleaseIndicatorHandles();
}

//+------------------------------------------------------------------+
//| Inicialização dos indicadores                                   |
//+------------------------------------------------------------------+
bool CMovingAverages::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_period = period;
    m_method = method;

    ReleaseIndicatorHandles(); // Limpar handles anteriores se existirem

    return CreateIndicatorHandles();
}

bool CMovingAverages::Init(string symbol, ENUM_TIMEFRAMES timeframe, CMAConfig &config)
{
    attach_chart = config.attach_chart; // Atribui a flag do config
    alert_tf = config.alert_tf;
    slope_values = config.slope_values[0];

    return Init(symbol, timeframe, config.period, config.method);
}

//+------------------------------------------------------------------+
//| Criar handles dos indicadores                                   |
//+------------------------------------------------------------------+
bool CMovingAverages::CreateIndicatorHandles()
{
    // Criar handle para média móvel com método especificado
    handle = iMA(m_symbol, m_timeframe, m_period, 0, m_method, PRICE_CLOSE);
    if (handle == INVALID_HANDLE)
    {
        Print("ERRO: Falha ao criar handle ", EnumToString(m_method), " ", m_period, " para ", m_symbol);
        return false;
    }

    Print("Indicador ", EnumToString(m_method), " inicializado para ", m_symbol, " - ", EnumToString(m_timeframe), " - Período: ", m_period);
    return true;
}

//+------------------------------------------------------------------+
//| Liberar handles dos indicadores                                 |
//+------------------------------------------------------------------+
void CMovingAverages::ReleaseIndicatorHandles()
{
    if (handle != INVALID_HANDLE)
    {
        IndicatorRelease(handle);
        handle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Obter valor do indicador                                        |
//+------------------------------------------------------------------+
double CMovingAverages::GetIndicatorValue(int ihandle, int shift = 0)
{
    if (ihandle == INVALID_HANDLE)
    {
        Print("ERRO: Handle do indicador inválido");
        return 0.0;
    }

    double buffer[];
    ArraySetAsSeries(buffer, true);

    if (CopyBuffer(ihandle, 0, shift, 1, buffer) <= 0)
    {
        Print("ERRO: Falha ao copiar dados do indicador");
        return 0.0;
    }

    return buffer[0];
}

//+------------------------------------------------------------------+
//| Obter valor da média móvel                                      |
//+------------------------------------------------------------------+
double CMovingAverages::GetValue(int shift = 0)
{
    return GetIndicatorValue(handle, shift);
}

//+------------------------------------------------------------------+
//| Copiar múltiplos valores da média móvel                        |
//+------------------------------------------------------------------+
bool CMovingAverages::CopyValues(int shift, int count, double &buffer[])
{
    if (handle == INVALID_HANDLE)
    {
        Print("ERRO: Handle do indicador inválido");
        return false;
    }

    ArrayResize(buffer, count);
    ArraySetAsSeries(buffer, true);

    if (CopyBuffer(handle, 0, shift, count, buffer) <= 0)
    {
        Print("ERRO: Falha ao copiar dados do indicador");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Verificar se os indicadores estão prontos                      |
//+------------------------------------------------------------------+
bool CMovingAverages::IsReady()
{
    return (BarsCalculated(handle) > 0);
}

//+------------------------------------------------------------------+
//| Atualizar handle e buffers                                       |
//+------------------------------------------------------------------+
bool CMovingAverages::Update()
{
    if (handle == INVALID_HANDLE)
        return CreateIndicatorHandles();

    if (BarsCalculated(handle) <= 0)
        return false;

    return true;
}

