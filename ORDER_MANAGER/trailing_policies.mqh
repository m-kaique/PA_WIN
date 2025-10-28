// trailing_policies.mqh
#ifndef __TRAILING_POLICIES_MQH__
#define __TRAILING_POLICIES_MQH__

// -------- Contexto --------
struct TrailingContext {
  string  symbol;
  bool    is_buy;
  double  price;
  double  point;
  double  be_level;
  double  current_sl;
  double  volume;
  double  vol_min;
  datetime now;
};

// -------- Interfaces --------
class ITrailingCandidate { public: virtual double ComputeSL(const TrailingContext &ctx)=0; };
class IAggregator        { public: virtual double Aggregate(const TrailingContext &ctx, const double &a[], int n)=0; };
class IConstraint        { public: virtual bool   Apply(const TrailingContext &ctx, double &new_sl)=0; };
class IContextRule       { public:
  virtual bool Applies(const TrailingContext &ctx)=0;
  virtual void OverrideCandidates(ITrailingCandidate* &cands[], int &n)=0;
};

// -------- Candidates --------
class FixedCandidate : public ITrailingCandidate {
public: int distance_points;
  FixedCandidate(int d): distance_points(d) {}
  double ComputeSL(const TrailingContext &c) {
    if (distance_points<=0) return EMPTY_VALUE;
    const double dist = distance_points * c.point;
    return c.is_buy ? (c.price - dist) : (c.price + dist);
  }
};

double CalculateChandelierSL(const string sym, bool is_buy, int atr_period, double atr_mult, int swing_lookback); // já existe no projeto

class ChandelierCandidate : public ITrailingCandidate {
public: int atr_period; double atr_mult; int swing_lookback;
  ChandelierCandidate(int p,double m,int s): atr_period(p),atr_mult(m),swing_lookback(s){}
  double ComputeSL(const TrailingContext &c) {
    double sl = CalculateChandelierSL(c.symbol, c.is_buy, atr_period, atr_mult, swing_lookback);
    return sl>0.0 ? sl : EMPTY_VALUE;
  }
};

// -------- Aggregator --------
class TightestWins : public IAggregator {
public:
  double Aggregate(const TrailingContext &c, const double &a[], int n) {
    double chosen = EMPTY_VALUE;
    for (int i=0;i<n;i++){
      if (a[i]==EMPTY_VALUE) continue;
      if (chosen==EMPTY_VALUE) { chosen=a[i]; continue; }
      chosen = c.is_buy ? MathMax(chosen, a[i]) : MathMin(chosen, a[i]);
    }
    return chosen;
  }
};

#endif // __TRAILING_POLICIES_MQH__

// -------- Constraints --------
bool BuildValidSL(const string sym, bool is_buy, double &sl); // já existe no projeto

class CooldownConstraint : public IConstraint {
public: int seconds; datetime last_update;
  CooldownConstraint(int s, datetime last): seconds(s), last_update(last) {}
  bool Apply(const TrailingContext &c, double &new_sl) {
    if (seconds>0 && (c.now - last_update) < seconds) return false;
    return true;
  }
};

class BreakEvenFloorConstraint : public IConstraint {
public:
  bool Apply(const TrailingContext &c, double &new_sl) {
    if (c.be_level<=0 || new_sl==EMPTY_VALUE) return true;
    new_sl = c.is_buy ? MathMax(new_sl, c.be_level) : MathMin(new_sl, c.be_level);
    return true;
  }
};

class HysteresisConstraint : public IConstraint {
public: int min_imp_points;
  HysteresisConstraint(int p): min_imp_points(p){}
  bool Apply(const TrailingContext &c, double &new_sl) {
    if (new_sl==EMPTY_VALUE) return false;
    if (c.current_sl<=0)   return true;
    const double min_imp = min_imp_points * c.point;
    if ( c.is_buy && new_sl <  c.current_sl + min_imp) return false;
    if (!c.is_buy && new_sl >  c.current_sl - min_imp) return false;
    return true;
  }
};

class BrokerLevelsConstraint : public IConstraint {
public:
  bool Apply(const TrailingContext &c, double &new_sl) {
    if (new_sl==EMPTY_VALUE) return false;
    return BuildValidSL(c.symbol, c.is_buy, new_sl);
  }
};

// -------- Regras de contexto --------
class LastLotOverrideRule : public IContextRule {
public: int distance_points_last;
  LastLotOverrideRule(int d): distance_points_last(d){}
  bool Applies(const TrailingContext &c) { return (c.volume <= c.vol_min + 1e-8); }
  void OverrideCandidates(ITrailingCandidate* &cands[], int &n) {
    static FixedCandidate fixed_last(0); fixed_last.distance_points = distance_points_last;
    cands[0]=&fixed_last; n=1;
  }
};

// -------- Engine --------
class TrailingEngine {
public:
  ITrailingCandidate* base_candidates[4]; int base_n;
  IAggregator*        aggregator;
  IConstraint*        constraints[6];     int cons_n;
  IContextRule*       rules[4];           int rules_n;

  TrailingEngine(): base_n(0), aggregator(NULL), cons_n(0), rules_n(0) {}
  void AddCandidate(ITrailingCandidate* c){ base_candidates[base_n++]=c; }
  void SetAggregator(IAggregator* a){ aggregator=a; }
  void AddConstraint(IConstraint* c){ constraints[cons_n++]=c; }
  void AddRule(IContextRule* r){ rules[rules_n++]=r; }

  bool Compute(const TrailingContext &ctx, double &out_sl){
    ITrailingCandidate* eff[4]; int n=base_n;
    for(int i=0;i<base_n;i++) eff[i]=base_candidates[i];
    for(int r=0;r<rules_n;r++){ if (rules[r].Applies(ctx)) rules[r].OverrideCandidates(eff, n); }

    double vals[4]; int m=0;
    for (int i=0;i<n;i++){ double v=eff[i].ComputeSL(ctx); if (v!=EMPTY_VALUE) vals[m++]=v; }
    if (m==0) return false;

    double cand = aggregator.Aggregate(ctx, vals, m);
    if (cand==EMPTY_VALUE) return false;

    for (int k=0;k<cons_n;k++){ if (!constraints[k].Apply(ctx, cand)) return false; }

    out_sl = cand; return true;
  }
};