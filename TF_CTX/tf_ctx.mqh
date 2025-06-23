//+------------------------------------------------------------------+
//|                                                       TF_CTX.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"

#include "indicators/moving_averages.mqh"
#include "config_types.mqh"

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

    // Configuração das médias móveis
    SMovingAverageConfig m_ema9_cfg;
    SMovingAverageConfig m_ema21_cfg;
    SMovingAverageConfig m_ema50_cfg;
    SMovingAverageConfig m_sma200_cfg;
    
    // Instâncias dos submódulos de médias móveis (cada uma com seu período específico)
    CMovingAverages*    m_ema9;     // EMA com período 9
    CMovingAverages*    m_ema21;    // EMA com período 21  
    CMovingAverages*    m_ema50;    // EMA com período 50
    CMovingAverages*    m_sma200;   // SMA com período 200
    
    // Métodos privados
    bool                ValidateParameters();
    void                CleanUp();

public:
    // Construtor com configuração de médias móveis
                        TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles,
                               SMovingAverageConfig ema9_cfg,
                               SMovingAverageConfig ema21_cfg,
                               SMovingAverageConfig ema50_cfg,
                               SMovingAverageConfig sma200_cfg);
    
    // Destrutor
                       ~TF_CTX();
    
    // Inicialização
    bool                Init();
    
    // Métodos públicos para médias móveis
    double              get_ema9(int shift = 0);
    double              get_ema21(int shift = 0);
    double              get_ema50(int shift = 0);
    double              get_sma_200(int shift = 0);

    // Obter array com os últimos m_num_candles valores de cada média
    bool                get_recent_values(double &ema9[], double &ema21[], double &ema50[], double &sma200[]);
    
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
TF_CTX::TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles,
               SMovingAverageConfig ema9_cfg,
               SMovingAverageConfig ema21_cfg,
               SMovingAverageConfig ema50_cfg,
               SMovingAverageConfig sma200_cfg)
{
    m_timeframe   = timeframe;
    m_num_candles = num_candles; // Usado apenas para referência
    m_symbol      = Symbol();
    m_initialized = false;

    m_ema9_cfg    = ema9_cfg;
    m_ema21_cfg   = ema21_cfg;
    m_ema50_cfg   = ema50_cfg;
    m_sma200_cfg  = sma200_cfg;

    m_ema9   = NULL;
    m_ema21  = NULL;
    m_ema50  = NULL;
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
    
    // Criar e inicializar médias móveis conforme configuração
    if(m_ema9_cfg.enabled)
    {
        m_ema9 = new CMovingAverages();
        if(m_ema9 == NULL || !m_ema9.Init(m_symbol, m_timeframe, m_ema9_cfg.period, m_ema9_cfg.method))
        {
            Print("ERRO: Falha ao inicializar EMA9");
            CleanUp();
            return false;
        }
    }

    if(m_ema21_cfg.enabled)
    {
        m_ema21 = new CMovingAverages();
        if(m_ema21 == NULL || !m_ema21.Init(m_symbol, m_timeframe, m_ema21_cfg.period, m_ema21_cfg.method))
        {
            Print("ERRO: Falha ao inicializar EMA21");
            CleanUp();
            return false;
        }
    }

    if(m_ema50_cfg.enabled)
    {
        m_ema50 = new CMovingAverages();
        if(m_ema50 == NULL || !m_ema50.Init(m_symbol, m_timeframe, m_ema50_cfg.period, m_ema50_cfg.method))
        {
            Print("ERRO: Falha ao inicializar EMA50");
            CleanUp();
            return false;
        }
    }

    if(m_sma200_cfg.enabled)
    {
        m_sma200 = new CMovingAverages();
        if(m_sma200 == NULL || !m_sma200.Init(m_symbol, m_timeframe, m_sma200_cfg.period, m_sma200_cfg.method))
        {
            Print("ERRO: Falha ao inicializar SMA200");
            CleanUp();
            return false;
        }
    }
    
    m_initialized = true;
    Print("TF_CTX inicializado com sucesso: ", m_symbol, " - ", EnumToString(m_timeframe));

    string ma_list = "";
    if(m_ema9 != NULL)   ma_list += "EMA9 ";
    if(m_ema21 != NULL)  ma_list += "EMA21 ";
    if(m_ema50 != NULL)  ma_list += "EMA50 ";
    if(m_sma200 != NULL) ma_list += "SMA200 ";

    Print("Médias configuradas: ", ma_list);
    
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
        Print("AVISO: EMA9 não habilitada ou contexto não inicializado");
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
        Print("AVISO: EMA21 não habilitada ou contexto não inicializado");
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
        Print("AVISO: EMA50 não habilitada ou contexto não inicializado");
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
        Print("AVISO: SMA200 não habilitada ou contexto não inicializado");
        return 0.0;
    }

    return m_sma200.GetValue(shift);
}

//+------------------------------------------------------------------+
//| Atualizar contexto                                              |
//+------------------------------------------------------------------+
bool TF_CTX::Update()
{
    if(!m_initialized)
    {
        Print("ERRO: TF_CTX não inicializado para atualização");
        return false;
    }

    bool ready = true;
    if(m_ema9 != NULL)   ready &= m_ema9.IsReady();
    if(m_ema21 != NULL)  ready &= m_ema21.IsReady();
    if(m_ema50 != NULL)  ready &= m_ema50.IsReady();
    if(m_sma200 != NULL) ready &= m_sma200.IsReady();

    return ready;
}

//+------------------------------------------------------------------+
//| Copiar últimos valores das médias                               |
//+------------------------------------------------------------------+
bool TF_CTX::get_recent_values(double &ema9[], double &ema21[], double &ema50[], double &sma200[])
{
    if(!m_initialized)
    {
        Print("ERRO: TF_CTX não inicializado");
        return false;
    }

    bool ok = true;
    if(m_ema9 != NULL)   ok &= m_ema9.CopyValues(0, m_num_candles, ema9);
    if(m_ema21 != NULL)  ok &= m_ema21.CopyValues(0, m_num_candles, ema21);
    if(m_ema50 != NULL)  ok &= m_ema50.CopyValues(0, m_num_candles, ema50);
    if(m_sma200 != NULL) ok &= m_sma200.CopyValues(0, m_num_candles, sma200);

    return ok;
}