#ifndef __ICONTEXT_PROVIDER_MQH__
#define __ICONTEXT_PROVIDER_MQH__

// Forward declarations to avoid circular dependencies
class TF_CTX;

//+------------------------------------------------------------------+
//| Interface for providing access to trading contexts              |
//+------------------------------------------------------------------+
interface IContextProvider
{
public:
    // Get context for specific symbol and timeframe
    virtual TF_CTX *GetContext(string symbol, ENUM_TIMEFRAMES tf) = 0;

    // Check if context is enabled
    virtual bool IsContextEnabled(string symbol, ENUM_TIMEFRAMES tf) = 0;

    // Get all configured symbols
    virtual void GetConfiguredSymbols(string &symbols[]) = 0;

    // Get all contexts for a specific symbol
    virtual int GetSymbolContexts(string symbol, TF_CTX *&contexts[], ENUM_TIMEFRAMES &timeframes[]) = 0;
};

#endif // __ICONTEXT_PROVIDER_MQH__