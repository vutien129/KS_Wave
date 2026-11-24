//+------------------------------------------------------------------+
//|                                                      KS_Wave.mq5 |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Antigravity AI"
#property description "Kinetic Structural Wave (KS-Wave) for MT5 with Bar-Close Alerts"
#property version     "2.10"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

// Plot 1: KS-Wave Line
#property indicator_label1  "KS-Wave"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLimeGreen, clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 2: Buy Arrow
#property indicator_label2  "KS-Buy"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLimeGreen
#property indicator_width2  2

// Plot 3: Sell Arrow
#property indicator_label3  "KS-Sell"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrCrimson
#property indicator_width3  2

// Enum chọn Profile
enum ENUM_PRESET
{
   PRESET_INTRADAY, // Day Trading (M15 - M30)
   PRESET_SCALP,    // Scalping (M1 - M5)
   PRESET_SWING,    // Swing Trading (H1 - H4)
   PRESET_POSITION, // Position Trading (D1)
   PRESET_CUSTOM    // Tùy chỉnh (Custom)
};

// ==========================================
// THAM SỐ ĐẦU VÀO (INPUTS)
// ==========================================
input group "=== 1. CHỌN HỒ SƠ PRESET ==="
input ENUM_PRESET InpPreset      = PRESET_INTRADAY; // Hồ sơ Khung thời gian

input group "=== 2. TÙY CHỈNH THỦ CÔNG (KHI CHỌN CUSTOM) ==="
input int         InpLen         = 14;              // Chu kỳ Động lượng (Length)
input double      InpKBase       = 2.2;             // Hệ số Khoảng cách Cơ sở
input int         InpPivLen      = 5;               // Chu kỳ Hàng rào Pivot

input group "=== 3. CẢNH BÁO ALERT (CHỈ KHI ĐÓNG NẾN) ==="
input bool        InpShowSignals = true;             // Hiển thị Mũi tên Buy/Sell
input bool        InpEnableAlert = true;             // Bật Popup Alert âm thanh
input bool        InpEnablePush  = false;            // Gửi thông báo Push đến điện thoại

// ==========================================
// BUFFERS & BIẾN NỘI BỘ
// ==========================================
double WaveBuffer[];
double ColorBuffer[];
double BuyBuffer[];
double SellBuffer[];

double ha_open[];
double ha_close[];
double p_core[];
double acl[];
double atr_down[];
double atr_up[];
int    trend[];

int    activeLen;
double activeKBase;
int    activePivLen;
datetime last_alert_time = 0;

//+------------------------------------------------------------------+
//| Khởi tạo Custom Indicator                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, WaveBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BuyBuffer,   INDICATOR_DATA);
   SetIndexBuffer(3, SellBuffer,  INDICATOR_DATA);

   PlotIndexSetInteger(1, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 234); // Down Arrow

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   switch(InpPreset)
   {
      case PRESET_SCALP:
         activeLen    = 24;  activeKBase  = 2.6;  activePivLen = 7;
         break;
      case PRESET_SWING:
         activeLen    = 12;  activeKBase  = 1.9;  activePivLen = 4;
         break;
      case PRESET_POSITION:
         activeLen    = 28;  activeKBase  = 2.8;  activePivLen = 5;
         break;
      case PRESET_CUSTOM:
         activeLen    = InpLen; activeKBase = InpKBase; activePivLen = InpPivLen;
         break;
      default: // PRESET_INTRADAY
         activeLen    = 14;  activeKBase  = 2.2;  activePivLen = 5;
         break;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "KS-Wave (" + IntegerToString(activeLen) + ")");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Vòng lặp tính toán chính                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < activeLen + 5)
      return(0);

   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(WaveBuffer, false);
   ArraySetAsSeries(ColorBuffer, false);
   ArraySetAsSeries(BuyBuffer, false);
   ArraySetAsSeries(SellBuffer, false);

   if(ArraySize(ha_open) < rates_total)
   {
      ArrayResize(ha_open, rates_total);
      ArrayResize(ha_close, rates_total);
      ArrayResize(p_core, rates_total);
      ArrayResize(acl, rates_total);
      ArrayResize(atr_down, rates_total);
      ArrayResize(atr_up, rates_total);
      ArrayResize(trend, rates_total);
   }

   int start = (prev_calculated > 1) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
      // 1. Heikin-Ashi Core
      ha_close[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      if(i == 0)
         ha_open[i] = open[i];
      else
         ha_open[i] = (ha_open[i-1] + ha_close[i-1]) / 2.0;

      p_core[i] = (ha_open[i] + high[i] + low[i] + 2.0 * close[i]) / 5.0;

      // 2. KER & ACL
      double ker = 0.0;
      if(i >= activeLen)
      {
         double chgTotal = MathAbs(p_core[i] - p_core[i - activeLen]);
         double volTotal = 0.0;
         for(int k = 0; k < activeLen; k++)
            volTotal += MathAbs(p_core[i - k] - p_core[i - k - 1]);

         if(volTotal > 0.0)
            ker = MathMin(1.0, chgTotal / volTotal);
      }

      double fastAlpha = 2.0 / 3.0;
      double slowAlpha = 2.0 / (activeLen + 1.0);
      double alpha = MathPow(ker * (fastAlpha - slowAlpha) + slowAlpha, 2.0);

      if(i == 0)
         acl[i] = p_core[i];
      else
         acl[i] = acl[i-1] + alpha * (p_core[i] - acl[i-1]);

      // 3. Asymmetric Volatility
      double prevClose = (i > 0) ? close[i-1] : close[i];
      double v_down = MathMax(high[i] - low[i], MathAbs(prevClose - low[i]));
      double v_up   = MathMax(high[i] - low[i], MathAbs(high[i] - prevClose));

      double emaAlpha = 2.0 / (activeLen + 1.0);
      if(i == 0)
      {
         atr_down[i] = v_down;
         atr_up[i]   = v_up;
      }
      else
      {
         atr_down[i] = atr_down[i-1] + emaAlpha * (v_down - atr_down[i-1]);
         atr_up[i]   = atr_up[i-1]   + emaAlpha * (v_up   - atr_up[i-1]);
      }

      double k_dyn = activeKBase * (1.6 - 0.8 * ker);
      double band_down = atr_down[i] * k_dyn;
      double band_up   = atr_up[i]   * k_dyn;

      // 4. Pivot Floor/Ceiling
      double floor_pivot = low[i];
      double ceil_pivot  = high[i];
      for(int p = 0; p < activePivLen && (i - p) >= 0; p++)
      {
         if(low[i - p] < floor_pivot)   floor_pivot = low[i - p];
         if(high[i - p] > ceil_pivot)   ceil_pivot  = high[i - p];
      }

      // 5. Ratchet KS-Wave Logic
      BuyBuffer[i]  = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;

      if(i == 0)
      {
         WaveBuffer[i]  = acl[i];
         trend[i]       = 1;
         ColorBuffer[i] = 0;
      }
      else
      {
         int curTrend    = trend[i-1];
         double prevWave = WaveBuffer[i-1];
         double waveVal  = prevWave;

         if(curTrend == 1)
         {
            double candidate = MathMax(acl[i] - band_down, floor_pivot);
            waveVal = MathMax(prevWave, candidate);
            if(close[i] < waveVal)
            {
               curTrend = -1;
               waveVal  = MathMin(acl[i] + band_up, ceil_pivot);
            }
         }
         else
         {
            double candidate = MathMin(acl[i] + band_up, ceil_pivot);
            waveVal = MathMin(prevWave, candidate);
            if(close[i] > waveVal)
            {
               curTrend = 1;
               waveVal  = MathMax(acl[i] - band_down, floor_pivot);
            }
         }

         trend[i]       = curTrend;
         WaveBuffer[i]  = waveVal;
         ColorBuffer[i] = (curTrend == 1) ? 0 : 1;

         // CHỈ VẼ MŨI TÊN TRÊN CÁC CÂY NẾN ĐÃ ĐÓNG (i < rates_total - 1)
         // Nến hiện tại đang chạy tuyệt đối không vẽ mũi tên nhấp nháy
         if(InpShowSignals && i > 0 && i < rates_total - 1)
         {
            if(curTrend == 1 && trend[i-1] == -1)
               BuyBuffer[i] = low[i] - (high[i] - low[i]) * 0.4;
            if(curTrend == -1 && trend[i-1] == 1)
               SellBuffer[i] = high[i] + (high[i] - low[i]) * 0.4;
         }
      }
   }

   // =======================================================
   // 6. PHÁT CẢNH BÁO ALERT (CHỈ KHI CÂY NẾN VỪA ĐÓNG CỬA)
   // =======================================================
   datetime current_bar_time = time[rates_total - 1];

   if(prev_calculated > 0 && current_bar_time != last_alert_time)
   {
      int closed_bar = rates_total - 2; // Cây nến vừa đóng cửa
      if(closed_bar > 0)
      {
         bool buy_signal  = (trend[closed_bar] == 1  && trend[closed_bar - 1] == -1);
         bool sell_signal = (trend[closed_bar] == -1 && trend[closed_bar - 1] == 1);

         string tfStr = EnumToString((ENUM_TIMEFRAMES)_Period);

         if(buy_signal)
         {
            // Định dạng chuỗi: XAUUSDm PERIOD_M1 | BUY: entry 3622.653 --stoploss 3615.830
            string msg = StringFormat("%s %s | BUY: entry %.*f --stoploss %.*f", 
                                      _Symbol, tfStr, _Digits, close[closed_bar], _Digits, WaveBuffer[closed_bar]);
            if(InpEnableAlert) Alert(msg);
            if(InpEnablePush)  SendNotification(msg);
         }
         else if(sell_signal)
         {
            // Định dạng chuỗi: XAUUSDm PERIOD_M1 | SELL: entry 3622.653 --stoploss 3615.830
            string msg = StringFormat("%s %s | SELL: entry %.*f --stoploss %.*f", 
                                      _Symbol, tfStr, _Digits, close[closed_bar], _Digits, WaveBuffer[closed_bar]);
            if(InpEnableAlert) Alert(msg);
            if(InpEnablePush)  SendNotification(msg);
         }
      }
      last_alert_time = current_bar_time;
   }
   else if(prev_calculated == 0)
   {
      last_alert_time = current_bar_time;
   }

   return(rates_total);
}
//+------------------------------------------------------------------+