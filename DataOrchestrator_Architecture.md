# DataOrchestrator Architecture Plan

## 1. Project Analysis Summary

### Current Architecture
- **Main EA**: PA_WIN.mq5 - Multi-timeframe Expert Advisor
- **Configuration Manager**: Handles JSON config and creates TF_CTX contexts
- **TF_CTX**: Timeframe contexts containing multiple indicators
- **Indicators**: Various technical indicators (MA, VWAP, Bollinger, TrendLine, Support/Resistance, etc.)
- **JSON Library**: JAson.mqh for JSON serialization/deserialization

### Data Flow
1. EA initializes ConfigManager from config.json
2. ConfigManager creates TF_CTX for each timeframe (M15, H1, H4, D1)
3. Each TF_CTX independently monitors its own timeframe for new bars
4. When a new bar forms for a specific timeframe, only that TF_CTX updates its indicators
5. EA processes indicator data for trading decisions
6. DataOrchestrator can be triggered on any new bar event or at specific intervals

## 2. DataOrchestrator Design

### Folder Structure
Following the project's modular architecture, the DataOrchestrator will be organized as:
```
PA_WIN/
├── DATA_ORCHESTRATOR/
│   ├── data_orchestrator.mqh          // Main orchestrator class
│   ├── data_orchestrator_defs.mqh     // Definitions and enums
│   ├── submodules/
│   │   ├── socket_manager/
│   │   │   ├── socket_manager.mqh
│   │   │   └── socket_defs.mqh
│   │   ├── data_collector/
│   │   │   ├── data_collector.mqh
│   │   │   └── collector_defs.mqh
│   │   └── json_serializer/
│   │       ├── json_serializer.mqh
│   │       └── serializer_defs.mqh
│   └── tests/
│       └── test_orchestrator.mqh
```

### Class Hierarchy
```
CDataOrchestrator
├── CSocketManager (composition)
├── CDataCollector (composition)
└── CJSONSerializer (composition)
```

### Core Responsibilities
1. **Data Collection**: Gather data from all TF_CTX and indicators
2. **Data Orchestration**: Structure data into organized format
3. **JSON Serialization**: Convert to optimized JSON format
4. **Socket Communication**: Send data to external server

### Design Patterns
- **Singleton Pattern**: For DataOrchestrator instance management
- **Observer Pattern**: For new bar notifications
- **Strategy Pattern**: For different serialization formats
- **Factory Pattern**: Already used in indicator creation

## 3. JSON Schema Design

### Optimized Structure
```json
{
  "timestamp": "2025-01-06T10:30:00Z",
  "symbol": "WIN$N",
  "account": {
    "balance": 10000.00,
    "equity": 10500.00,
    "margin": 500.00
  },
  "market": {
    "bid": 120500,
    "ask": 120505,
    "spread": 5,
    "volume": 1250
  },
  "timeframes": {
    "M15": {
      "bar": {
        "time": "2025-01-06T10:30:00",
        "open": 120450,
        "high": 120520,
        "low": 120440,
        "close": 120500,
        "volume": 350
      },
      "indicators": {
      "ema9": {
        "value": 120480,
        "slope": {
          "linear_regression": {
            "slope_value": 0.45,
            "trend_direction": "_UP",
            "strength": 0.75
          },
          "simple_difference": {
            "slope_value": 0.32,
            "trend_direction": "_UP",
            "strength": 0.65
          },
          "discrete_derivative": {
            "slope_value": 0.28,
            "trend_direction": "_UP",
            "strength": 0.55
          }
        },
        "position": {
          "status": "CANDLE_COMPLETELY_BELOW",
          "distance": 15.5,
          "gap": 8.2,
          "atr": 25.3
        }
      },
        "ema21": {
          "value": 120470,
          "slope": {
            "direction": "UP",
            "strength": 0.65
          },
          "position": "BELOW"
        },
        "vwap": {
          "value": 120490,
          "slope": {
            "linear_regression": {
              "slope_value": 0.02,
              "trend_direction": "_SIDEWALK"
            }
          },
          "position": {
            "status": "INDICATOR_CROSSES_LOWER_BODY",
            "distance": 10
          }
        },
        "adx": {
          "value": 28.3,
          "trend_strength": "STRONG"
        },
        "atr": {
          "value": 45.5,
          "normalized": 0.037
        },
        "volume": {
          "current": 350,
          "average": 285,
          "ratio": 1.23
        }
        "bollinger": {
          "upper": {
            "value": 120550,
            "slope": {
              "linear_regression": {
                "slope_value": 0.15,
                "trend_direction": "_SIDEWALK"
              }
            },
            "position": {
              "status": "CANDLE_BELOW_WITH_DISTANCE",
              "distance": -70
            }
          },
          "middle": {
            "value": 120480,
            "slope": {
              "linear_regression": {
                "slope_value": 0.08,
                "trend_direction": "_UP"
              }
            },
            "position": {
              "status": "INDICATOR_CROSSES_CENTER_BODY",
              "distance": 0
            }
          },
          "lower": {
            "value": 120410,
            "slope": {
              "linear_regression": {
                "slope_value": 0.12,
                "trend_direction": "_UP"
              }
            },
            "position": {
              "status": "CANDLE_COMPLETELY_ABOVE",
              "distance": 70
            }
          },
          "width": 140,
          "deviation": 2.0
        },
        "atr": 45.5,
        "adx": 28.3,
        "volume": 350
      }
    },
    "H1": {
      "bar": {
        "time": "2025-01-06T10:00:00",
        "open": 120400,
        "high": 120520,
        "low": 120380,
        "close": 120500,
        "volume": 2100
      },
      "indicators": {
        "ema50": {
          "value": 120450,
          "slope": {
            "direction": "UP",
            "strength": 0.55
          }
        },
        "trendline": {
          "lta": {
            "active": true,
            "value": 120420,
            "angle": 25.5,
            "touches": 3,
            "breakout": false,
            "last_break": "2025-01-05T14:30:00Z"
          },
          "ltb": {
            "active": true,
            "value": 120580,
            "angle": 22.3,
            "touches": 2,
            "breakout": false,
            "last_break": "2025-01-04T09:15:00Z"
          },
          "lta2": {
            "active": true,
            "value": 120400,
            "angle": 18.7
          },
          "ltb2": {
            "active": true,
            "value": 120600,
            "angle": 19.2
          },
          "candle_analysis": {
            "body_cross_lta": false,
            "body_cross_ltb": true,
            "between_ltas": true,
            "between_ltbs": false,
            "distance_lta": 60,
            "distance_ltb": -20,
            "fakeout_lta": false,
            "fakeout_ltb": true
          },
          "position": "TREND_BETWEEN",
          "breakdown": false,
          "breakup": false
        }
      }
    },
    "H4": {
      "indicators": {
        "sma200": {
          "value": 120200,
          "slope": {
            "direction": "UP",
            "strength": 0.45
          }
        },
        "support_resistance": {
          "resistance_zones": [
            {
              "upper": 120850,
              "lower": 120750,
              "touches": 4,
              "distance": 300,
              "patterns": {
                "pinbar": 2,
                "engulf": 1,
                "doji": 0,
                "marubozu_bull": 0,
                "marubozu_bear": 1,
                "inside_bar": 1,
                "outside_bar": 0
              }
            },
            {
              "upper": 121050,
              "lower": 120950,
              "touches": 3,
              "distance": 500,
              "patterns": {
                "pinbar": 1,
                "engulf": 0,
                "doji": 1,
                "marubozu_bull": 0,
                "marubozu_bear": 0,
                "inside_bar": 0,
                "outside_bar": 1
              }
            }
          ],
          "support_zones": [
            {
              "upper": 120250,
              "lower": 120150,
              "touches": 5,
              "distance": -300,
              "patterns": {
                "pinbar": 3,
                "engulf": 2,
                "doji": 1,
                "marubozu_bull": 1,
                "marubozu_bear": 0,
                "inside_bar": 2,
                "outside_bar": 0
              }
            },
            {
              "upper": 120050,
              "lower": 119950,
              "touches": 3,
              "distance": -500,
              "patterns": {
                "pinbar": 1,
                "engulf": 1,
                "doji": 0,
                "marubozu_bull": 0,
                "marubozu_bear": 0,
                "inside_bar": 1,
                "outside_bar": 0
              }
            }
          ],
          "breakdown": false,
          "breakup": false,
          "validation_mode": "VALIDATE_BOTH"
        }
      }
    },
    "D1": {
      "bar": {
        "time": "2025-01-06T00:00:00",
        "open": 120080,
        "high": 120520,
        "low": 119900,
        "close": 120500,
        "volume": 12500
      },
      "indicators": {
        "fibonacci": {
          "levels": {
            "23.6": 120380,
            "38.2": 120320,
            "50.0": 120260,
            "61.8": 120200,
            "78.6": 120140,
            "100.0": 120080,
            "127.0": 120020,
            "161.8": 119960,
            "261.8": 119900
          },
          "extensions": {
            "127.0": 120020,
            "161.8": 119960,
            "261.8": 119900
          },
          "parallels": {
            "yellow": 120050
          },
          "tolerance_distance": 70,
          "max_tolerance_distance": 5
        }
      }
    }
  },
  "signals": {
    "trend": "BULLISH",
    "strength": 0.65,
    "confluence": 3
  }
}
```

## 4. File Organization and Includes

### Main Include Structure
```mql5
// In PA_WIN.mq5
#include "DATA_ORCHESTRATOR/data_orchestrator.mqh"

// In data_orchestrator.mqh
#include "data_orchestrator_defs.mqh"
#include "submodules/socket_manager/socket_manager.mqh"
#include "submodules/data_collector/data_collector.mqh"
#include "submodules/json_serializer/json_serializer.mqh"
```

## 5. Class Interfaces

### CDataOrchestrator
```mql5
class CDataOrchestrator {
private:
    static CDataOrchestrator* m_instance;
    CSocketManager* m_socket;
    CDataCollector* m_collector;
    CJSONSerializer* m_serializer;
    
    // Configuration
    string m_server_host;
    int m_server_port;
    bool m_enabled;
    int m_send_interval;
    
    // Tracking last updates per timeframe
    datetime m_last_update[]; // Array indexed by ENUM_TIMEFRAMES
    
public:
    static CDataOrchestrator* Instance();
    bool Initialize(string host, int port);
    void CollectData(CConfigManager* config_manager);
    string OrchestratData();
    bool SendData(const string& json);
    
    // Event handlers for specific timeframe updates
    void OnTimeframeUpdate(string symbol, ENUM_TIMEFRAMES tf, TF_CTX* ctx);
    void SendConsolidatedData(CConfigManager* config_manager);
    
    // Configuration methods
    void SetSendMode(ENUM_SEND_MODE mode); // ON_ANY_BAR, ON_SPECIFIC_TF, INTERVAL
    void SetTriggerTimeframe(ENUM_TIMEFRAMES tf); // If using ON_SPECIFIC_TF mode
    
    void Shutdown();
    bool IsEnabled() { return m_enabled; }
};
```

### Send Modes
```mql5
enum ENUM_SEND_MODE {
    SEND_ON_ANY_BAR,      // Send when any timeframe has a new bar
    SEND_ON_SPECIFIC_TF,  // Send only when specific timeframe has new bar
    SEND_ON_INTERVAL,     // Send at fixed time intervals
    SEND_ON_M15_ONLY,     // Send only on M15 new bars (most frequent)
    SEND_ON_H1_ONLY       // Send only on H1 new bars
};
```

### CSocketManager
```mql5
class CSocketManager {
private:
    int m_socket;
    string m_host;
    int m_port;
    bool m_connected;
    
public:
    bool Connect(string host, int port);
    bool Send(const string& data);
    bool IsConnected();
    void Disconnect();
    string GetLastError();
};
```

### CDataCollector
```mql5
class CDataCollector {
private:
    CJAVal m_data;
    
public:
    void CollectMarketData(string symbol);
    void CollectAccountData();
    void CollectTimeframeData(TF_CTX* ctx, ENUM_TIMEFRAMES tf);
    void CollectIndicatorData(CIndicatorBase* indicator, string name);
    CJAVal* GetCollectedData();
    void Clear();
};
```

### CJSONSerializer
```mql5
class CJSONSerializer {
private:
    bool m_compress;
    int m_precision;
    
public:
    string Serialize(CJAVal* data);
    string SerializeCompact(CJAVal* data);
    void SetPrecision(int digits);
    void EnableCompression(bool enable);
};
```

## 6. Integration Points

### In PA_WIN.mq5

#### OnInit()
```mql5
// After ConfigManager initialization
if (!g_data_orchestrator.Initialize(SocketHost, SocketPort)) {
    Print("WARNING: DataOrchestrator initialization failed");
}
```

#### UpdateSymbolContexts()
```mql5
// Modified to trigger DataOrchestrator when any context updates
void UpdateSymbolContexts(string symbol)
{
    TF_CTX *contexts[];
    ENUM_TIMEFRAMES tfs[];
    int count = g_config_manager.GetSymbolContexts(symbol, contexts, tfs);
    
    bool any_new_bar = false;
    for (int i = 0; i < count; i++)
    {
        TF_CTX *ctx = contexts[i];
        ENUM_TIMEFRAMES tf = tfs[i];
        if (ctx == NULL) continue;
        
        if (ctx.HasNewBar())
        {
            ctx.Update();
            any_new_bar = true;
            
            // Notify DataOrchestrator of the specific TF update
            if (g_data_orchestrator.IsEnabled()) {
                g_data_orchestrator.OnTimeframeUpdate(symbol, tf, ctx);
            }
        }
    }
    
    // Optional: Send consolidated data after any update
    if (any_new_bar && g_data_orchestrator.IsEnabled()) {
        g_data_orchestrator.SendConsolidatedData(g_config_manager);
    }
}
```

#### OnDeinit()
```mql5
// Before cleanup
if (g_data_orchestrator != NULL) {
    g_data_orchestrator.Shutdown();
}
```

## 7. Implementation Phases

### File Creation Order
1. Create folder structure: DATA_ORCHESTRATOR/ and submodules/
2. Implement definition files (*_defs.mqh)
3. Implement submodule classes
4. Implement main orchestrator class
5. Create test files

## 8. Implementation Phases (Development)

### Phase 1: Core Structure
1. Create base classes and interfaces
2. Implement data collection logic
3. Basic JSON serialization

### Phase 2: Socket Communication
1. Implement SocketManager
2. Add connection management
3. Error handling and reconnection

### Phase 3: Advanced Features
1. Data compression
2. Buffering for offline mode
3. Performance optimization

## 9. Error Handling Strategy

### Connection Errors
- Automatic reconnection with exponential backoff
- Local data buffering when disconnected
- Maximum retry limits

### Data Errors
- Validation before serialization
- Graceful handling of missing indicators
- Logging all errors

### Performance Considerations
- Asynchronous socket operations
- Minimal impact on EA performance
- Configurable send frequency

## 10. Configuration Parameters

### Input Parameters (PA_WIN.mq5)
```mql5
input bool   EnableDataOrchestrator = true;
input string SocketHost = "localhost";
input int    SocketPort = 8080;
input int    SendIntervalMs = 1000;
input bool   CompressJSON = true;
input int    SocketTimeout = 5000;
input int    MaxRetries = 3;
```

## 11. Testing Strategy

### Unit Tests
- Test each component independently
- Mock socket connections
- Validate JSON output

### Integration Tests
- Test with real TF_CTX data
- Verify socket communication
- Performance benchmarks

### System Tests
- Full EA integration
- Network failure scenarios
- Load testing

## 12. Documentation Requirements

### Code Documentation
- Detailed comments for each method
- Usage examples
- Error code definitions

### Integration Guide
- Step-by-step setup instructions
- Configuration examples
- Troubleshooting guide

## 13. Security Considerations

- Optional SSL/TLS support
- Authentication tokens
- Data encryption options
- IP whitelist support

## 14. Future Enhancements

- WebSocket support
- Multiple server endpoints
- Data filtering options
- Real-time configuration updates
- Metrics and monitoring