//+------------------------------------------------------------------+
//|                                           indicators/adx.mqh    |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#include "../indicator_base/indicator_base.mqh"
#include "adx_defs.mqh"
#include "../indicators_types.mqh"

//+------------------------------------------------------------------+
//| Classe para cálculo do ADX (Average Directional Index)         |
//+------------------------------------------------------------------+
class CADX : public CIndicatorBase
{
private:
    int m_period;                // Período para cálculo do ADX

    // Métodos privados
    bool CreateIndicatorHandles();
    void ReleaseIndicatorHandles();
    double GetIndicatorValue(int handle, int shift = 0);

public:
    // Construtor
    CADX();

    // Destrutor
    ~CADX();

    // Inicialização
    bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method = MODE_SMA);
    bool Init(string symbol, ENUM_TIMEFRAMES timeframe, CAdxConfig &config);

    // Método para obter valor do ADX
    double GetValue(int shift = 0);

    // Obter valor do +DI
    double GetPlusDI(int shift = 0);

    // Obter valor do -DI
    double GetMinusDI(int shift = 0);

    // Obter múltiplos valores do ADX
    bool CopyValues(int shift, int count, double &buffer[]);

    // Obter múltiplos valores do +DI
    bool CopyPlusDI(int shift, int count, double &buffer[]);

    // Obter múltiplos valores do -DI
    bool CopyMinusDI(int shift, int count, double &buffer[]);

    // Verificar se o indicador está pronto
    bool IsReady();

    // Atualizar estado interno
    virtual bool Update() override;
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CADX::CADX()
{
    m_symbol = "";
    m_timeframe = PERIOD_CURRENT;
    m_period = 14;
    handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CADX::~CADX()
{
    ReleaseIndicatorHandles();
}

//+------------------------------------------------------------------+
//| Inicialização do indicador                                      |
//+------------------------------------------------------------------+
bool CADX::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method = MODE_SMA)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_period = period;

    ReleaseIndicatorHandles();
    return CreateIndicatorHandles();
}

bool CADX::Init(string symbol, ENUM_TIMEFRAMES timeframe, CAdxConfig &config)
{
    attach_chart = config.attach_chart;
    alert_tf = config.alert_tf;
    return Init(symbol, timeframe, config.period);
}

//+------------------------------------------------------------------+
//| Criar handle do indicador                                       |
//+------------------------------------------------------------------+
bool CADX::CreateIndicatorHandles()
{
    handle = iADX(m_symbol, m_timeframe, m_period);
    if (handle == INVALID_HANDLE)
    {
        Print("ERRO: Falha ao criar handle ADX ", m_period, " para ", m_symbol);
        return false;
    }

    Print("Indicador ADX inicializado para ", m_symbol, " - ", EnumToString(m_timeframe), " - Período: ", m_period);
    return true;
}

//+------------------------------------------------------------------+
//| Liberar handle do indicador                                     |
//+------------------------------------------------------------------+
void CADX::ReleaseIndicatorHandles()
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
double CADX::GetIndicatorValue(int ihandle, int shift = 0)
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
        Print("ERRO: Falha ao copiar dados do indicador ADX");
        return 0.0;
    }

    return buffer[0];
}

//+------------------------------------------------------------------+
//| Obter valor do ADX                                             |
//+------------------------------------------------------------------+
double CADX::GetValue(int shift = 0)
{
    return GetIndicatorValue(handle, shift);
}

//+------------------------------------------------------------------+
//| Obter valor do +DI                                             |
//+------------------------------------------------------------------+
double CADX::GetPlusDI(int shift = 0)
{
    if (handle == INVALID_HANDLE)
        return 0.0;

    double buffer[];
    ArraySetAsSeries(buffer, true);

    if (CopyBuffer(handle, 1, shift, 1, buffer) <= 0)
    {
        Print("ERRO: Falha ao copiar dados do +DI");
        return 0.0;
    }

    return buffer[0];
}

//+------------------------------------------------------------------+
//| Obter valor do -DI                                             |
//+------------------------------------------------------------------+
double CADX::GetMinusDI(int shift = 0)
{
    if (handle == INVALID_HANDLE)
        return 0.0;

    double buffer[];
    ArraySetAsSeries(buffer, true);

    if (CopyBuffer(handle, 2, shift, 1, buffer) <= 0)
    {
        Print("ERRO: Falha ao copiar dados do -DI");
        return 0.0;
    }

    return buffer[0];
}

//+------------------------------------------------------------------+
//| Copiar múltiplos valores do ADX                               |
//+------------------------------------------------------------------+
bool CADX::CopyValues(int shift, int count, double &buffer[])
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
        Print("ERRO: Falha ao copiar dados do indicador ADX");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Copiar múltiplos valores do +DI                               |
//+------------------------------------------------------------------+
bool CADX::CopyPlusDI(int shift, int count, double &buffer[])
{
    if (handle == INVALID_HANDLE)
    {
        Print("ERRO: Handle do indicador inválido");
        return false;
    }

    ArrayResize(buffer, count);
    ArraySetAsSeries(buffer, true);

    if (CopyBuffer(handle, 1, shift, count, buffer) <= 0)
    {
        Print("ERRO: Falha ao copiar dados do +DI");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Copiar múltiplos valores do -DI                               |
//+------------------------------------------------------------------+
bool CADX::CopyMinusDI(int shift, int count, double &buffer[])
{
    if (handle == INVALID_HANDLE)
    {
        Print("ERRO: Handle do indicador inválido");
        return false;
    }

    ArrayResize(buffer, count);
    ArraySetAsSeries(buffer, true);

    if (CopyBuffer(handle, 2, shift, count, buffer) <= 0)
    {
        Print("ERRO: Falha ao copiar dados do -DI");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Verificar se o indicador está pronto                           |
//+------------------------------------------------------------------+
bool CADX::IsReady()
{
    return (BarsCalculated(handle) > 0);
}

//+------------------------------------------------------------------+
//| Atualizar handle e buffers                                      |
//+------------------------------------------------------------------+
bool CADX::Update()
{
    if (handle == INVALID_HANDLE)
        return CreateIndicatorHandles();

    if (BarsCalculated(handle) <= 0)
        return false;

    return true;
}