#ifndef __STRATEGY_CTX_MQH__
#define __STRATEGY_CTX_MQH__

#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include "../interfaces/icontext_provider.mqh"
#include "factories/strategy_factory.mqh"
#include "strategies/strategies_types.mqh"
#include "strategies/strategy_base/strategy_base.mqh"

class STRATEGY_CTX
{
private:
    // Configurações e instâncias das estratégias
    CStrategyConfig *m_cfg[];
    CStrategyBase *m_strategies[];
    string m_names[];
    bool m_initialized;
    string m_setup_name; // Nome do Setup (Conservative_Setup, Risky_Setup, etc)
    IContextProvider *m_context_provider;

   bool CreateStrategies();
   void AddStrategy(CStrategyBase *strategy, string name);
   int FindByName(string name, string &arr[]);
   void CleanUp();

public:
   STRATEGY_CTX(string setup_name, CStrategyConfig *&cfg[], IContextProvider *context_provider = NULL);
   ~STRATEGY_CTX();

   bool Init();
   bool Update();
   CStrategyBase *GetStrategy(string name);
   bool IsInitialized() const { return m_initialized; }
   string GetSetupName() const { return m_setup_name; }
   //void GetStrategyNames(string &names[]);
   int GetStrategyCount() const { return ArraySize(m_strategies); };
   void SetContextProvider(IContextProvider *context_provider);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
STRATEGY_CTX::STRATEGY_CTX(string setup_name, CStrategyConfig *&cfg[], IContextProvider *context_provider)
{
    m_setup_name = setup_name;
    m_initialized = false;
    m_context_provider = context_provider;
    int sz = ArraySize(cfg);
    ArrayResize(m_cfg, sz);
    for (int i = 0; i < sz; i++)
       m_cfg[i] = cfg[i];

    ArrayResize(m_strategies, 0);
    ArrayResize(m_names, 0);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
STRATEGY_CTX::~STRATEGY_CTX()
{
   CleanUp();
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool STRATEGY_CTX::Init()
{
   if (!CreateStrategies())
   {
      CleanUp();
      return false;
   }

   m_initialized = true;
   Print("STRATEGY_CTX inicializado para setup: ", m_setup_name, " com ", ArraySize(m_strategies), " estratégias");
   return true;
}

//+------------------------------------------------------------------+
//| Criar estratégias                                                |
//+------------------------------------------------------------------+
bool STRATEGY_CTX::CreateStrategies()
{
   CStrategyFactory *factory = CStrategyFactory::Instance();

   for (int i = 0; i < ArraySize(m_cfg); i++)
   {
      CStrategyConfig *cfg = m_cfg[i];
      if (cfg == NULL || !cfg.enabled)
         continue;

      if (!factory.IsRegistered(cfg.type))
      {
         Print("Tipo de estratégia não suportado: ", cfg.type);
         continue;
      }

      CStrategyBase *strategy = factory.Create(cfg.type, cfg.name, cfg, m_context_provider);
      if (strategy == NULL)
      {
         Print("ERRO: Falha ao inicializar estratégia ", cfg.name);
         return false;
      }

      AddStrategy(strategy, cfg.name);
      Print("Estratégia criada: ", cfg.name, " (", cfg.type, ") ");
   }
   return true;
}

//+------------------------------------------------------------------+
//| Adicionar estratégia                                             |
//+------------------------------------------------------------------+
void STRATEGY_CTX::AddStrategy(CStrategyBase *strategy, string name)
{
   int pos = ArraySize(m_strategies);
   ArrayResize(m_strategies, pos + 1);
   ArrayResize(m_names, pos + 1);
   m_strategies[pos] = strategy;
   m_names[pos] = name;
}

//+------------------------------------------------------------------+
//| Encontrar por nome                                               |
//+------------------------------------------------------------------+
int STRATEGY_CTX::FindByName(string name, string &arr[])
{
   for (int i = 0; i < ArraySize(arr); i++)
      if (arr[i] == name)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
//| Atualizar estratégias                                            |
//+------------------------------------------------------------------+
bool STRATEGY_CTX::Update()
{
   if (!m_initialized)
      return false;

   bool all_updated = true;
   for (int i = 0; i < ArraySize(m_strategies); i++)
   {
      if (m_strategies[i] != NULL)
      {
         all_updated &= m_strategies[i].Update();
      }
   }

   return all_updated;
}

//+------------------------------------------------------------------+
//| Obter estratégia por nome                                        |
//+------------------------------------------------------------------+
CStrategyBase *STRATEGY_CTX::GetStrategy(string name)
{
   int idx = FindByName(name, m_names);
   if (idx >= 0)
      return m_strategies[idx];
   return NULL;
}

//+------------------------------------------------------------------+
//| Definir provedor de contexto                                     |
//+------------------------------------------------------------------+
void STRATEGY_CTX::SetContextProvider(IContextProvider *context_provider)
{
    m_context_provider = context_provider;
}

//+------------------------------------------------------------------+
//| Limpar recursos                                                  |
//+------------------------------------------------------------------+
void STRATEGY_CTX::CleanUp()
{
    // Destruir configurações associadas (evita leaks dos *Config)
    for (int i = 0; i < ArraySize(m_cfg); i++)
    {
       if (m_cfg[i] != NULL)
       {
          delete m_cfg[i];
          m_cfg[i] = NULL;
       }
    }
    ArrayResize(m_cfg, 0);

    // Destruir estratégias criadas para este contexto
    for (int i = 0; i < ArraySize(m_strategies); i++)
    {
       if (m_strategies[i] != NULL)
       {
          delete m_strategies[i];
          m_strategies[i] = NULL;
       }
    }
    ArrayResize(m_strategies, 0);
    ArrayResize(m_names, 0);
    m_initialized = false;
    m_context_provider = NULL;
}

#endif