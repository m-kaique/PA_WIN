//+------------------------------------------------------------------+
//|                                                       TF_CTX.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"

#include "indicators/moving_averages.mqh"

//+------------------------------------------------------------------+
//| Classe principal para contexto de TimeFrame                     |
//+------------------------------------------------------------------+
class TF_CTX
{
private:
    ENUM_TIMEFRAMES     m_timeframe;        // TimeFrame para análise
    int                 m_num_candles;      // Número de velas para análise (não usado para período das médias)
    string              m_symbol;           // Símbolo atual
    bool                m_initialized;      // Flag de inicialização
    
    // Instâncias dos submódulos de médias móveis (cada uma com seu período específico)
    CMovingAverages*    m_ema9;     // EMA com período 9
    CMovingAverages*    m_ema21;    // EMA com período 21  
    CMovingAverages*    m_ema50;    // EMA com período 50
    CMovingAverages*    m_sma200;   // SMA com período 200
    
    // Métodos privados
    bool                ValidateParameters();
    void                CleanUp();

public:
    // Construtor
                        TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles = 0);
    
    // Destrutor
                       ~TF_CTX();
    
    // Inicialização
    bool                Init();
    
    // Métodos públicos para médias móveis
    double              get_ema9(int shift = 0);
    double              get_ema21(int shift = 0);
    double              get_ema50(int shift = 0);
    double              get_sma_200(int shift = 0);
    
    // Métodos auxiliares
    bool                IsInitialized() const { return m_initialized; }
    ENUM_TIMEFRAMES     GetTimeframe() const { return m_timeframe; }
    int                 GetNumCandles() const { return m_num_candles; }
    string              GetSymbol() const { return m_symbol; }
    
    // Atualizar contexto
    bool                Update();
};

//+------------------------------------------------------------------+
//| Construtor da classe TF_CTX                                     |
//+------------------------------------------------------------------+
TF_CTX::TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles = 0)
{
    m_timeframe = timeframe;
    m_num_candles = num_candles; // Usado apenas para referência, não para período das médias
    m_symbol = Symbol();
    m_initialized = false;
    m_ema9 = NULL;
    m_ema21 = NULL;
    m_ema50 = NULL;
    m_sma200 = NULL;
}

//+------------------------------------------------------------------+
//| Destrutor da classe TF_CTX                                      |
//+------------------------------------------------------------------+
TF_CTX::~TF_CTX()
{
    CleanUp();
}

//+------------------------------------------------------------------+
//| Inicialização da classe                                          |
//+------------------------------------------------------------------+
bool TF_CTX::Init()
{
    if(!ValidateParameters())
    {
        Print("ERRO: Parâmetros inválidos para TF_CTX");
        return false;
    }
    
    // Criar instâncias dos submódulos de médias móveis
    m_ema9 = new CMovingAverages();
    m_ema21 = new CMovingAverages();
    m_ema50 = new CMovingAverages();
    m_sma200 = new CMovingAverages();
    
    if(m_ema9 == NULL || m_ema21 == NULL || m_ema50 == NULL || m_sma200 == NULL)
    {
        Print("ERRO: Falha ao criar instâncias dos submódulos de médias móveis");
        CleanUp();
        return false;
    }
    
    // CORREÇÃO: Inicializar cada submódulo com SEU PERÍODO ESPECÍFICO
    if(!m_ema9.Init(m_symbol, m_timeframe, 9, MODE_EMA) ||      // EMA com período 9
       !m_ema21.Init(m_symbol, m_timeframe, 21, MODE_EMA) ||    // EMA com período 21
       !m_ema50.Init(m_symbol, m_timeframe, 50, MODE_EMA) ||    // EMA com período 50
       !m_sma200.Init(m_symbol, m_timeframe, 200, MODE_SMA))    // SMA com período 200
    {
        Print("ERRO: Falha ao inicializar submódulos de médias móveis");
        CleanUp();
        return false;
    }
    
    m_initialized = true;
    Print("TF_CTX inicializado com sucesso: ", m_symbol, " - ", EnumToString(m_timeframe));
    Print("Médias configuradas: EMA9, EMA21, EMA50, SMA200");
    
    return true;
}

//+------------------------------------------------------------------+
//| Validar parâmetros de entrada                                   |
//+------------------------------------------------------------------+
bool TF_CTX::ValidateParameters()
{
    // Validar TimeFrame
    if(m_timeframe < PERIOD_M1 || m_timeframe > PERIOD_MN1)
    {
        Print("ERRO: TimeFrame inválido: ", EnumToString(m_timeframe));
        return false;
    }
    
    // Validar símbolo
    if(StringLen(m_symbol) == 0)
    {
        Print("ERRO: Símbolo inválido");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Limpar recursos                                                  |
//+------------------------------------------------------------------+
void TF_CTX::CleanUp()
{
    if(m_ema9 != NULL)
    {
        delete m_ema9;
        m_ema9 = NULL;
    }
    
    if(m_ema21 != NULL)
    {
        delete m_ema21;
        m_ema21 = NULL;
    }
    
    if(m_ema50 != NULL)
    {
        delete m_ema50;
        m_ema50 = NULL;
    }
    
    if(m_sma200 != NULL)
    {
        delete m_sma200;
        m_sma200 = NULL;
    }
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Obter EMA 9                                                     |
//+------------------------------------------------------------------+
double TF_CTX::get_ema9(int shift = 0)
{
    if(!m_initialized || m_ema9 == NULL)
    {
        Print("ERRO: TF_CTX não inicializado");
        return 0.0;
    }
    
    return m_ema9.GetValue(shift);
}

//+------------------------------------------------------------------+
//| Obter EMA 21                                                    |
//+------------------------------------------------------------------+
double TF_CTX::get_ema21(int shift = 0)
{
    if(!m_initialized || m_ema21 == NULL)
    {
        Print("ERRO: TF_CTX não inicializado");
        return 0.0;
    }
    
    return m_ema21.GetValue(shift);
}

//+------------------------------------------------------------------+
//| Obter EMA 50                                                    |
//+------------------------------------------------------------------+
double TF_CTX::get_ema50(int shift = 0)
{
    if(!m_initialized || m_ema50 == NULL)
    {
        Print("ERRO: TF_CTX não inicializado");
        return 0.0;
    }
    
    return m_ema50.GetValue(shift);
}

//+------------------------------------------------------------------+
//| Obter SMA 200                                                   |
//+------------------------------------------------------------------+
double TF_CTX::get_sma_200(int shift = 0)
{
    if(!m_initialized || m_sma200 == NULL)
    {
        Print("ERRO: TF_CTX não inicializado");
        return 0.0;
    }
    
    return m_sma200.GetValue(shift);
}

//+------------------------------------------------------------------+
//| Atualizar contexto                                              |
//+------------------------------------------------------------------+
bool TF_CTX::Update()
{
    if(!m_initialized || m_ema9 == NULL || m_ema21 == NULL || m_ema50 == NULL || m_sma200 == NULL)
    {
        Print("ERRO: TF_CTX não inicializado para atualização");
        return false;
    }
    
    return (m_ema9.IsReady() && m_ema21.IsReady() && m_ema50.IsReady() && m_sma200.IsReady());
}