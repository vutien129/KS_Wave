//+------------------------------------------------------------------+
//|                                                   KS_Wave_EA.mq5 |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Antigravity AI"
#property description "Expert Advisor with KS-Wave Trailing Stop & Spread Compensation"
#property version     "1.20"

#include <Trade\Trade.mqh>

// Enum chọn Profile sóng
enum ENUM_PRESET
{
   PRESET_INTRADAY, // Day Trading (M15 - M30)
   PRESET_SCALP,    // Scalping (M1 - M5)
   PRESET_SWING,    // Swing Trading (H1 - H4)
   PRESET_POSITION, // Position Trading (D1)
   PRESET_CUSTOM    // Tùy chỉnh (Custom)
};

// Enum chọn kiểu Chốt Lời
enum ENUM_TP_MODE
{
   TP_MODE_WAVE_REVERSAL, // 1. Chốt lời theo Đảo chiều Sóng Wave
   TP_MODE_FIXED_PIPS,    // 2. Chốt lời theo Pip cố định
   TP_MODE_BOTH           // 3. Kết hợp (Đảo sóng HOẶC Chạm Pip)
};

// ==========================================
// THAM SỐ CẤU HÌNH (INPUTS)
// ==========================================
input group "=== 1. QUẢN LÝ LỆNH & VỐN ==="
input ulong          InpMagicNumber        = 202611;       // Magic Number
input double         InpFixedLot           = 0.01;         // Khối lượng giao dịch (Lot)
input ulong          InpSlippage           = 10;           // Trượt giá tối đa (Points)

input group "=== 2. CHIẾN LƯỢC CHỐT LỜI & CẮT LỖ ==="
input ENUM_TP_MODE   InpTPMode             = TP_MODE_BOTH; // Kiểu Chốt Lời (Take Profit)
input double         InpTakeProfitPips     = 50.0;         // Mức chốt lời Pip (khi chọn Pip hoặc Kết hợp)
input bool           InpUseWaveAsStop      = true;         // Dùng đường KS-Wave làm Stop Loss ban đầu
input double         InpCustomSLPips       = 30.0;         // SL theo Pip (khi không dùng KS-Wave)

input group "=== 3. TỰ ĐỘNG HÒA VỐN (BREAK-EVEN) ==="
input bool           InpEnableBE           = true;         // Bật tính năng dời Hòa Vốn (BE)
input double         InpBreakEvenPips      = 20.0;         // Đạt lợi nhuận (Pip) thì dời BE
input double         InpExtraBEPips        = 1.0;          // Cộng thêm vào BE ngoài Spread (Pip)

input group "=== 4. TRAILING STOP THEO SÓNG (ĐÃ TÍNH SPREAD) ==="
input bool           InpEnableWaveTrail    = true;         // Bật Trailing Stop bám theo Sóng KS-Wave
input bool           InpTrailIncludeSpread = true;         // Tính bù trừ Spread vào Trailing SL
input double         InpTrailBufferPips    = 0.5;          // Pips đệm an toàn thêm (Pip)

input group "=== 5. CẤU HÌNH SÓNG KS-WAVE ==="
input ENUM_PRESET    InpPreset             = PRESET_INTRADAY; // Profile Khung thời gian
input int            InpLen                = 14;           // Custom: Length
input double         InpKBase              = 2.2;          // Custom: Hệ số k
input int            InpPivLen             = 5;            // Custom: Pivot Length

input group "=== 6. GIAO DIỆN & BỘ ĐẾM NẾN ==="
input bool           InpShowTimer          = true;         // Hiện bộ đếm thời gian đóng nến
input color          InpTimerColor         = clrYellow;    // Màu chữ bộ đếm nến

// ==========================================
// BIẾN TOÀN CỤC & ĐỐI TƯỢNG
// ==========================================
CTrade   trade;
int      activeLen;
double   activeKBase;
int      activePivLen;
datetime last_bar_time = 0;
string   timerObjName  = "KS_Wave_Timer_Label";

//+------------------------------------------------------------------+
//| Tính kích thước 1 Pip chuẩn (Vàng = 0.1, Forex = 10 point)       |
//+------------------------------------------------------------------+
double GetPipSize()
{
   string sym = _Symbol;
   StringToLower(sym);
   if(StringFind(sym, "xau") >= 0 || StringFind(sym, "gold") >= 0)
      return 0.10; // 1 giá Vàng = 10 pip
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return 10.0 * _Point;
   return _Point;
}

//+------------------------------------------------------------------+
//| Khởi tạo EA                                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   switch(InpPreset)
   {
      case PRESET_SCALP:
         activeLen = 24; activeKBase = 2.6; activePivLen = 7; break;
      case PRESET_SWING:
         activeLen = 12; activeKBase = 1.9; activePivLen = 4; break;
      case PRESET_POSITION:
         activeLen = 28; activeKBase = 2.8; activePivLen = 5; break;
      case PRESET_CUSTOM:
         activeLen = InpLen; activeKBase = InpKBase; activePivLen = InpPivLen; break;
      default: // PRESET_INTRADAY
         activeLen = 14; activeKBase = 2.2; activePivLen = 5; break;
   }

   EventSetTimer(1);

   if(InpShowTimer)
   {
      ObjectCreate(0, timerObjName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, timerObjName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, timerObjName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, timerObjName, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, timerObjName, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, timerObjName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, timerObjName, OBJPROP_COLOR, InpTimerColor);
   }

   Print("KS-Wave EA khởi chạy thành công trên ", _Symbol, " | PipSize: ", GetPipSize());
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Hủy EA                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectDelete(0, timerObjName);
}

//+------------------------------------------------------------------+
//| Đếm ngược thời gian nến (Cập nhật mỗi giây)                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!InpShowTimer) return;

   datetime cur_time = TimeCurrent();
   datetime bar_time = iTime(_Symbol, _Period, 0);
   int period_sec    = PeriodSeconds(_Period);
   int rem_sec       = (int)((bar_time + period_sec) - cur_time);

   if(rem_sec < 0) rem_sec = 0;

   int hours = rem_sec / 3600;
   int mins  = (rem_sec % 3600) / 60;
   int secs  = rem_sec % 60;

   string timeStr;
   if(hours > 0)
      timeStr = StringFormat("[ ⏱ %02d:%02d:%02d ]", hours, mins, secs);
   else
      timeStr = StringFormat("[ ⏱ %02d:%02d ]", mins, secs);

   ObjectSetString(0, timerObjName, OBJPROP_TEXT, "Đóng nến: " + timeStr);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Thuật toán tính KS-Wave nội bộ trong EA                          |
//+------------------------------------------------------------------+
bool CalculateKSWave(double &outWave[], int &outTrend[], int count = 100)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, _Period, 0, count, rates);
   if(copied < activeLen + 5) return false;

   ArrayResize(outWave, copied);
   ArrayResize(outTrend, copied);

   double ha_open[], ha_close[], p_core[], acl[], atr_down[], atr_up[];
   ArrayResize(ha_open, copied);  ArrayResize(ha_close, copied);
   ArrayResize(p_core, copied);   ArrayResize(acl, copied);
   ArrayResize(atr_down, copied); ArrayResize(atr_up, copied);

   for(int i = 0; i < copied; i++)
   {
      ha_close[i] = (rates[i].open + rates[i].high + rates[i].low + rates[i].close) / 4.0;
      ha_open[i]  = (i == 0) ? rates[i].open : (ha_open[i-1] + ha_close[i-1]) / 2.0;
      p_core[i]   = (ha_open[i] + rates[i].high + rates[i].low + 2.0 * rates[i].close) / 5.0;

      double ker = 0.0;
      if(i >= activeLen)
      {
         double chg = MathAbs(p_core[i] - p_core[i - activeLen]);
         double vol = 0.0;
         for(int k = 0; k < activeLen; k++)
            vol += MathAbs(p_core[i - k] - p_core[i - k - 1]);
         if(vol > 0.0) ker = MathMin(1.0, chg / vol);
      }

      double fastAlpha = 2.0 / 3.0;
      double slowAlpha = 2.0 / (activeLen + 1.0);
      double alpha = MathPow(ker * (fastAlpha - slowAlpha) + slowAlpha, 2.0);

      acl[i] = (i == 0) ? p_core[i] : acl[i-1] + alpha * (p_core[i] - acl[i-1]);

      double prevClose = (i > 0) ? rates[i-1].close : rates[i].close;
      double v_down = MathMax(rates[i].high - rates[i].low, MathAbs(prevClose - rates[i].low));
      double v_up   = MathMax(rates[i].high - rates[i].low, MathAbs(rates[i].high - prevClose));

      double emaAlpha = 2.0 / (activeLen + 1.0);
      if(i == 0)
      {
         atr_down[i] = v_down; atr_up[i] = v_up;
      }
      else
      {
         atr_down[i] = atr_down[i-1] + emaAlpha * (v_down - atr_down[i-1]);
         atr_up[i]   = atr_up[i-1]   + emaAlpha * (v_up   - atr_up[i-1]);
      }

      double k_dyn     = activeKBase * (1.6 - 0.8 * ker);
      double band_down = atr_down[i] * k_dyn;
      double band_up   = atr_up[i]   * k_dyn;

      double floor_pivot = rates[i].low;
      double ceil_pivot  = rates[i].high;
      for(int p = 0; p < activePivLen && (i - p) >= 0; p++)
      {
         if(rates[i - p].low < floor_pivot)   floor_pivot = rates[i - p].low;
         if(rates[i - p].high > ceil_pivot)   ceil_pivot  = rates[i - p].high;
      }

      if(i == 0)
      {
         outWave[i]  = acl[i];
         outTrend[i] = 1;
      }
      else
      {
         int curTrend   = outTrend[i-1];
         double prevW   = outWave[i-1];
         double waveVal = prevW;

         if(curTrend == 1)
         {
            double candidate = MathMax(acl[i] - band_down, floor_pivot);
            waveVal = MathMax(prevW, candidate);
            if(rates[i].close < waveVal)
            {
               curTrend = -1;
               waveVal  = MathMin(acl[i] + band_up, ceil_pivot);
            }
         }
         else
         {
            double candidate = MathMin(acl[i] + band_up, ceil_pivot);
            waveVal = MathMin(prevW, candidate);
            if(rates[i].close > waveVal)
            {
               curTrend = 1;
               waveVal  = MathMax(acl[i] - band_down, floor_pivot);
            }
         }
         outTrend[i] = curTrend;
         outWave[i]  = waveVal;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Quản lý Dời Hòa Vốn (Break-Even) Bù Spread Chuẩn                 |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   if(!InpEnableBE) return;

   double pipSize     = GetPipSize();
   double spreadPts   = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   long   stopsLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minSafeDist = MathMax((double)stopsLevel * _Point, 20 * _Point);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         long   posType   = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double curSL     = PositionGetDouble(POSITION_SL);
         double curTP     = PositionGetDouble(POSITION_TP);

         // XỬ LÝ LỆNH BUY
         if(posType == POSITION_TYPE_BUY)
         {
            double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double profitPips = (curBid - openPrice) / pipSize;

            if(profitPips >= InpBreakEvenPips)
            {
               double newSL = NormalizeDouble(openPrice + spreadPts + InpExtraBEPips * pipSize, _Digits);

               if(curSL < newSL - _Point)
               {
                  if(curBid - newSL >= minSafeDist)
                  {
                     if(trade.PositionModify(ticket, newSL, curTP))
                     {
                        PrintFormat(">> [BE THÀNH CÔNG] Dời Buy #%I64u về SL: %.*f", ticket, _Digits, newSL);
                     }
                  }
               }
            }
         }
         // XỬ LÝ LỆNH SELL
         else if(posType == POSITION_TYPE_SELL)
         {
            double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profitPips = (openPrice - curAsk) / pipSize;

            if(profitPips >= InpBreakEvenPips)
            {
               double newSL = NormalizeDouble(openPrice - spreadPts - InpExtraBEPips * pipSize, _Digits);

               if(curSL > newSL + _Point || curSL == 0.0)
               {
                  if(newSL - curAsk >= minSafeDist)
                  {
                     if(trade.PositionModify(ticket, newSL, curTP))
                     {
                        PrintFormat(">> [BE THÀNH CÔNG] Dời Sell #%I64u về SL: %.*f", ticket, _Digits, newSL);
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Quản lý Trailing Stop Bám Sóng KS-Wave (Đã Tính Spread)          |
//+------------------------------------------------------------------+
void ManageWaveTrailingStop(double waveVal, int trendVal)
{
   if(!InpEnableWaveTrail) return;

   double pipSize     = GetPipSize();
   double spreadPts   = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   long   stopsLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minSafeDist = MathMax((double)stopsLevel * _Point, 20 * _Point);

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         long   posType   = PositionGetInteger(POSITION_TYPE);
         double curSL     = PositionGetDouble(POSITION_SL);
         double curTP     = PositionGetDouble(POSITION_TP);

         // TRAILING CHO LỆNH BUY (Khi Sóng là TĂNG)
         if(posType == POSITION_TYPE_BUY && trendVal == 1)
         {
            // SL = Đường Sóng - Spread (tránh quét dãn spread) - Buffer
            double spreadOffset = InpTrailIncludeSpread ? spreadPts : 0.0;
            double bufferOffset = InpTrailBufferPips * pipSize;
            double newSL        = NormalizeDouble(waveVal - spreadOffset - bufferOffset, _Digits);

            // Chỉ dời LÊN và phải cách giá thị trường Bid ít nhất minSafeDist
            if(newSL > curSL + _Point && (curBid - newSL >= minSafeDist))
            {
               if(trade.PositionModify(ticket, newSL, curTP))
               {
                  PrintFormat(">> [TRAILING WAVE BUY] #%I64u | Wave: %.*f | Dời SL bám sóng lên: %.*f", 
                              ticket, _Digits, waveVal, _Digits, newSL);
               }
            }
         }
         // TRAILING CHO LỆNH SELL (Khi Sóng là GIẢM)
         else if(posType == POSITION_TYPE_SELL && trendVal == -1)
         {
            // SL = Đường Sóng + Spread (bù chênh lệch giá Ask) + Buffer
            double spreadOffset = InpTrailIncludeSpread ? spreadPts : 0.0;
            double bufferOffset = InpTrailBufferPips * pipSize;
            double newSL        = NormalizeDouble(waveVal + spreadOffset + bufferOffset, _Digits);

            // Chỉ dời XUỐNG và phải cách giá thị trường Ask ít nhất minSafeDist
            if((newSL < curSL - _Point || curSL == 0.0) && (newSL - curAsk >= minSafeDist))
            {
               if(trade.PositionModify(ticket, newSL, curTP))
               {
                  PrintFormat(">> [TRAILING WAVE SELL] #%I64u | Wave: %.*f | Dời SL bám sóng xuống: %.*f", 
                              ticket, _Digits, waveVal, _Digits, newSL);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Đóng toàn bộ lệnh theo chiều quy định                            |
//+------------------------------------------------------------------+
void CloseAllPositions(long typeToClose)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         if(PositionGetInteger(POSITION_TYPE) == typeToClose)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vòng lặp xử lý chính (OnTick)                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Kiểm tra dời BE liên tục trên từng tick giá
   ManageBreakEven();

   // 2. Chỉ tính toán Sóng, Trailing Wave và Vào lệnh KHI CÓ NẾN MỚI ĐÃ ĐÓNG CỬA
   datetime cur_bar_time = iTime(_Symbol, _Period, 0);
   if(cur_bar_time == last_bar_time) return;

   double waveArr[];
   int    trendArr[];
   if(!CalculateKSWave(waveArr, trendArr, 150)) return;

   int lastClosedIdx = ArraySize(trendArr) - 2;
   if(lastClosedIdx < 1) return;

   int    confirmedTrend = trendArr[lastClosedIdx];
   int    previousTrend  = trendArr[lastClosedIdx - 1];
   double lastWaveVal    = waveArr[lastClosedIdx];

   // 3. THỰC HIỆN TRAILING STOP THEO ĐƯỜNG SÓNG VỪA ĐÓNG CỬA
   ManageWaveTrailingStop(lastWaveVal, confirmedTrend);

   // 4. KIỂM TRA TÍN HIỆU ĐẢO SÓNG
   bool buySignal  = (confirmedTrend == 1  && previousTrend == -1);
   bool sellSignal = (confirmedTrend == -1 && previousTrend == 1);

   double pipSize = GetPipSize();

   // 5. ĐÓNG LỆNH KHI ĐẢO CHIỀU SÓNG
   if(InpTPMode == TP_MODE_WAVE_REVERSAL || InpTPMode == TP_MODE_BOTH)
   {
      if(buySignal)  CloseAllPositions(POSITION_TYPE_SELL);
      if(sellSignal) CloseAllPositions(POSITION_TYPE_BUY);
   }

   // 6. MỞ LỆNH MỚI TẠI GIÂY ĐẦU TIÊN CỦA NẾN MỚI
   if(buySignal)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = InpUseWaveAsStop ? lastWaveVal : (ask - InpCustomSLPips * pipSize);
      double tp  = 0.0;

      if(InpTPMode == TP_MODE_FIXED_PIPS || InpTPMode == TP_MODE_BOTH)
         tp = ask + InpTakeProfitPips * pipSize;

      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);

      if(trade.Buy(InpFixedLot, _Symbol, ask, sl, tp, "KS-Wave BUY"))
      {
         PrintFormat(">> [BUY EXECUTED] %s %s | Entry: %.*f | SL: %.*f | TP: %.*f", 
                     _Symbol, EnumToString(_Period), _Digits, ask, _Digits, sl, _Digits, tp);
      }
   }
   else if(sellSignal)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = InpUseWaveAsStop ? lastWaveVal : (bid + InpCustomSLPips * pipSize);
      double tp  = 0.0;

      if(InpTPMode == TP_MODE_FIXED_PIPS || InpTPMode == TP_MODE_BOTH)
         tp = bid - InpTakeProfitPips * pipSize;

      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);

      if(trade.Sell(InpFixedLot, _Symbol, bid, sl, tp, "KS-Wave SELL"))
      {
         PrintFormat(">> [SELL EXECUTED] %s %s | Entry: %.*f | SL: %.*f | TP: %.*f", 
                     _Symbol, EnumToString(_Period), _Digits, bid, _Digits, sl, _Digits, tp);
      }
   }

   last_bar_time = cur_bar_time;
}
//+------------------------------------------------------------------+