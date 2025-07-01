# Guia para Adicionar Novos Indicadores ou PriceActions

Este documento resume os passos para criar e registrar novos componentes no EA **PA_WIN**.

## 1. Criar a Classe

1. **Definir cabeçalho `.mqh`** dentro da pasta apropriada (`TF_CTX/indicators` ou `TF_CTX/priceaction`).
2. **Herdar** da classe base (`CIndicatorBase` ou `CPriceActionBase`).
3. Implementar os métodos principais:
   - `Init()` – configura parâmetros e aloca recursos.
   - `GetValue()` / `CopyValues()` – retornam valores calculados.
   - `IsReady()` – indica se o objeto está pronto.
   - `Update()` – recalcula valores ou redesenha objetos quando necessário.
4. (Opcional) Criar arquivo `*_defs.mqh` com enums ou constantes auxiliares.

## 2. Configuração

1. Adicione uma estrutura no arquivo `TF_CTX/config_types.mqh` derivada de `CIndicatorConfig` ou `CPriceActionConfig` para armazenar os parâmetros configuráveis.
2. Defina valores padrão no construtor dessa estrutura.

## 3. Fábricas

1. Registre o novo tipo no `IndicatorFactory` ou `PriceActionFactory`.
   - Inclua o cabeçalho do componente.
   - Adicione a função estática de criação e chame `Register()` dentro de `RegisterDefaults()`.

Exemplo:
```cpp
Register("SUPRES", CreateSupRes);
```

## 4. ConfigManager

1. No `config_manager.mqh`, extenda o parser JSON para reconhecer o novo tipo.
2. Para cada entrada encontrada, aloque a configuração específica e preencha os campos com os valores lidos do JSON.

## 5. Uso no `config.json`

Inclua um bloco semelhante ao abaixo no timeframe desejado:
```json
{
   "name": "sr_simple",
   "type": "SUPRES",
   "period": 50,
   "draw_sup": true,
   "draw_res": true,
   "sup_color": "Blue",
   "res_color": "Red",
   "sup_style": "SOLID",
   "res_style": "SOLID",
   "sup_width": 1,
   "res_width": 1,
   "extend_right": true,
   "show_labels": false,
   "alert_tf": "H1",
   "enabled": true
}
```

Após salvar o JSON e recarregar a configuração (função `ReloadConfig()`), o novo componente será criado automaticamente.
