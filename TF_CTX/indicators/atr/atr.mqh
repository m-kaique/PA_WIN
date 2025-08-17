//+------------------------------------------------------------------+
//|                                           indicators/atr.mqh    |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#include "atr_defs.mqh"
#include "../indicator_base/indicator_base.mqh"
#include "../indicators_types.mqh"

//+------------------------------------------------------------------+
//| Classe para cálculo do ATR (Average True Range)                |
//+------------------------------------------------------------------+
class CATR : public CIndicatorBase
{
private:
    int m_period;                // Período para cálculo do ATR

    // Métodos privados
    bool CreateIndicatorHandles();
    void ReleaseIndicatorHandles();
    double GetIndicatorValue(int handle, int shift = 0);

public:
    // Construtor
    CATR();

    // Destrutor
    ~CATR();

    // Inicialização
    bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method = MODE_SMA);
    bool Init(string symbol, ENUM_TIMEFRAMES timeframe, CAtrConfig &config);

    // Método para obter valor do ATR
    double GetValue(int shift = 0);

    // Obter múltiplos valores do ATR
    bool CopyValues(int shift, int count, double &buffer[]);

    // Verificar se o indicador está pronto
    bool IsReady();

    // Atualizar estado interno
    virtual bool Update() override;
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CATR::CATR()
{
    m_symbol = "";
    m_timeframe = PERIOD_CURRENT;
    m_period = 14;
    handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CATR::~CATR()
{
    ReleaseIndicatorHandles();
}

//+------------------------------------------------------------------+
//| Inicialização do indicador                                      |
//+------------------------------------------------------------------+
bool CATR::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method = MODE_SMA)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_period = period;

    ReleaseIndicatorHandles();
    return CreateIndicatorHandles();
}

bool CATR::Init(string symbol, ENUM_TIMEFRAMES timeframe, CAtrConfig
    &config)
{
    attach_chart = config.attach_chart;
    alert_tf = config.alert_tf;
    return Init(symbol, timeframe, config.period);
}

//+------------------------------------------------------------------+
//| Criar handle do indicador                                       |
//+------------------------------------------------------------------+
bool CATR::CreateIndicatorHandles()
{
    handle = iATR(m_symbol, m_timeframe, m_period);
    if (handle == INVALID_HANDLE)
    {
        Print("ERRO: Falha ao criar handle ATR ", m_period, " para ", m_symbol);
        return false;
    }

    Print("Indicador ATR inicializado para ", m_symbol, " - ", EnumToString(m_timeframe), " - Período: ", m_period);
    return true;
}

//+------------------------------------------------------------------+
//| Liberar handle do indicador                                     |
//+------------------------------------------------------------------+
void CATR::ReleaseIndicatorHandles()
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
double CATR::GetIndicatorValue(int ihandle, int shift = 0)
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
        Print("ERRO: Falha ao copiar dados do indicador ATR");
        return 0.0;
    }

    return buffer[0];
}

//+------------------------------------------------------------------+
//| Obter valor do ATR                                             |
//+------------------------------------------------------------------+
double CATR::GetValue(int shift = 0)
{
    return GetIndicatorValue(handle, shift);
}

//+------------------------------------------------------------------+
//| Copiar múltiplos valores do ATR                               |
//+------------------------------------------------------------------+
bool CATR::CopyValues(int shift, int count, double &buffer[])
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
        Print("ERRO: Falha ao copiar dados do indicador ATR");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Verificar se o indicador está pronto                           |
//+------------------------------------------------------------------+
bool CATR::IsReady()
{
    return (BarsCalculated(handle) > 0);
}

//+------------------------------------------------------------------+
//| Atualizar handle e buffers                                      |
//+------------------------------------------------------------------+
bool CATR::Update()
{
    if (handle == INVALID_HANDLE)
        return CreateIndicatorHandles();

    if (BarsCalculated(handle) <= 0)
        return false;

    return true;
}