#include "../../../utils/JAson.mqh"
#include "../../../utils/conversion.mqh"
#include "../../../STRATEGIES/strategy_ctx.mqh"
#include "../../config_types.mqh"


//+------------------------------------------------------------------+
//| Classe para parsing de configurações de Estratégias              |
//+------------------------------------------------------------------+

class CStrategyConfigParser{
   private:
   public:
      CStrategyConfigParser();
      ~CStrategyConfigParser();

      // Método principal para parsing de configuração de estratégia
      SStrategyConfig ParseStrategyConfig(CJAVal *strategy_config);
}