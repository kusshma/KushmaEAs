//+------------------------------------------------------------------+
//|                                                    Mr Blade.mq5  |
//|                                   Copyright 2026, Ramil Askarov  | 
//|                                                https://mql5.com  |
//+------------------------------------------------------------------+

#property copyright "Copyright 2026, Ramil Askarov"
#property link      "https://mql5.com"
#property version   "1.1"
#property strict

#resource "\\Images\\mr_blade.bmp"

//--- Design constants (Harmonious dark palette)
#define BG_COLOR          0x241D1A // Deep dark gray/blue background
#define BORDER_COLOR      0x3F322C // Elegant border
#define TEXT_MAIN         0xF0E8E2 // Soft white for headers
#define TEXT_MUTED        0xB8A394 // Gray for labels
#define COLOR_PROFIT      0x81B910 // Emerald green for profit
#define COLOR_LOSS        0x4444EF // Coral red for loss
#define FONT_NAME         "Segoe UI"

// Include trading class for easy order management
#include <Trade\Trade.mqh>
CTrade trade;

// Complete list of direction combinations
enum Direction
{
   Direction_None,           // Disabled
   Direction_H4,             // H4 Only
   Direction_H6,             // H6 Only
   Direction_H12,            // H12 Only
   Direction_Month,          // Month Only
   Direction_Week,           // Week Only
   Direction_Day,            // Day Only
   Direction_MonthWeek,      // Month + Week
   Direction_MonthDay,       // Month + Day
   Direction_WeekDay,        // Week + Day
   Direction_MonthWeekDay,   // Month + Week + Day
   Direction_MonthDayH4,     // Month + Day + H4
   Direction_DayH12,         // Day + H12
   Direction_WeekH12,        // Week + H12
   Direction_MonthH12,       // Month + H12
   Direction_DayH6,          // Day + H6
   Direction_WeekH6,         // Week + H6
   Direction_MonthH6,        // Month + H6
   Direction_DayH4,          // Day + H4
   Direction_WeekH4,         // Week + H4
   Direction_MonthH4         // Month + H4
};


string strDirection="";


//--- Global variables for ATR
int      atrHandle                        = INVALID_HANDLE;    // ATR indicator handle
input int InpATRPeriod                    = 17;                // ATR period for volatility calculation
input ENUM_TIMEFRAMES InpAtrTimeframe     = PERIOD_M15;    // Timeframe for ATR
ENUM_TIMEFRAMES tfAtrTimeframe            = PERIOD_M15; 
input double InpATRCoeff                  = 0.01;              // ATR coefficient
input double currentIndentCoef            = 7;                 // Trail coefficient

//--- Input parameters

input group "--- Initial Balance Settings ---"
input double InpInitBalance               = 1000;              // EA initial balance

input group "--- Panel Settings ---"
input bool   InpShowDashboard  = true;                 // Show dashboard on chart?

input group "--- Order Settings ---"
input ulong           InpMagicNumber      = 123;       // EA Magic Number
input int             InpMaxSpread        = 35;        // Maximum spread
input double          InpRiskPercent      = 10;        // Allowed risk per trade (%)
input double          InpLotSize          = 0.01;      // Lot size (0 - auto lot)
int                   InpIndentPoints     = 10;        // Indent from High/Low to place orders (in points)
int                   InpStopLoss         = 1000;      // Stop Loss (in points, 0 - without SL)
input double          InpStopLossCoeff    = 0.5;       // Stop Loss coefficient
input int             InpMinStepPoints    = 10;        // Minimum price change step (in points)

input group "--- Trailing Stop Settings (Coefficients) ---"
input bool            InpUseTrailing     = true;       // Use trailing stop?
input double          InpTrailTrigCoeff  = 0;          // Profit coefficient to enable trailing
input double          InpTrailDistCoeff  = 0.04;       // Trailing distance coefficient from price
input double          InpTrailStepCoeff  = 0.02;       // Minimum trailing step coefficient
int                   InpTrailTrigger    = 0;          // Trailing activation trigger (profit in points)
int                   InpTrailDistance   = 0;          // Trailing distance from current price (in points)
int                   InpTrailStep       = 0;          // Trailing step (in points)


input group "--- Breakeven Settings ---"
input bool            InpUseBreakeven = false;         // Move to breakeven?
input int             InpBreakevenTrigger = 0;         // Profit in points to activate breakeven
input int             InpBreakevenProfit  = 0;         // Breakeven level above open price (in points)


input group "--- Time Restrictions (Server Time) ---"
input bool            InpUseTimeFilter= false;          // Filter operations by time?
input bool            InpCloseOnTimeOut = false;        // Close all positions when outside time limits?

input int             InpStartHour    = 1;             // Trading start hour
input int             InpStartMinute  = 15;            // Trading start minute
input int             InpEndHour      = 23;            // Trading end hour
input int             InpEndMinute    = 55;            // Trading end minute

input int             InpNWStartHour    = 16;          // Non-working start hour
input int             InpNWStartMinute  = 25;          // Non-working start minute
input int             InpNWEndHour      = 17;          // Non-working end hour
input int             InpNWEndMinute    = 0;           // Non-working end minute


input bool            InpTradeMonday      = true;      // Trade on Monday?
input bool            InpTradeTuesday     = true;      // Trade on Tuesday?
input bool            InpTradeWednesday   = true;      // Trade on Wednesday?
input bool            InpTradeThursday    = true;      // Trade on Thursday?
input bool            InpTradeFriday      = true;      // Trade on Friday?



input group "--- Extremum Search Settings ---"

input ENUM_TIMEFRAMES InpTimeframe           = PERIOD_H3;   // Timeframe for extrema
ENUM_TIMEFRAMES       tfTimeframe            = PERIOD_H3; 
input ENUM_TIMEFRAMES InpAnalizeTimeframe    = PERIOD_M1;   // Timeframe for analysis
ENUM_TIMEFRAMES       tfAnalizeTimeframe     = PERIOD_M1; 

input int             InpBarsToAnalyze= 8;                
  // Number of bars (N) to search for High/Low
int                   StartBarToAnalyze= 1;                 // Initial bar position to search for High/Low
input double          InpMinDistCoeff    = 0.35;            // Min distance coefficient from price to extremum
int                   InpMinDistancePoints = 0;             // Min distance from current price to extremum (in points)

input group "--- Timeframe Screen Settings ---"
input Direction       InpDirection      = Direction_None;   // Screens  
input bool            InpNoDirecTrade   = true;             // Trade if no direction is detected?


//+------------------------------------------------------------------+
//| Structure for storing trading statistics                         |
//+------------------------------------------------------------------+
struct ExpertStats
  {
   double   init_balance;     // Initial balance (from settings)
   double   current_balance;  // Current robot balance (balance + profit)
   double   total_profit;     // Current net result
   double   max_profit;       // Maximum achieved result
   double   current_drawdown; // Current drawdown from maximum
   int      deals_win;        // Number of winning trades
   int      deals_loss;       // Number of losing trades
  }; 
  
//--- Global variables for calculations
double   m_total_profit = 0.0;
double   m_max_profit   = 0.0;
double   m_drawdown     = 0.0;
int      m_deals_win    = 0;
int      m_deals_loss   = 0;
bool     m_is_visible   = true;

//--- Global variables
datetime lastBarTime = 0;
double   InpDefaultStopLoss=5;
double   ATRValue;
ExpertStats stats;
datetime inittime;
bool blWasTrade=false;
bool blWasTest=false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);   
   m_is_visible = InpShowDashboard;
   inittime=TimeCurrent();
   
   // Initialize and create the panel
   if(m_is_visible)
     {
      CreateDashboard();
      UpdateDashboardUI();
     }
     
   atrHandle = iATR(_Symbol, tfAtrTimeframe, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("Failed to create iATR handle. Error: ", GetLastError());
      return(INIT_FAILED);
     }       
       
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Delete all created graphical objects when removing the EA
   ObjectsDeleteAll(0, "DB_");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{ 


   string voldiscrip;
   
   if(MQLInfoInteger(MQL_TESTER)&&!m_is_visible)
   {
      stats.current_balance=AccountInfoDouble(ACCOUNT_EQUITY);
   }   
   else CalculateExpertStats(InpMagicNumber);

   // Update data only if the panel is active on the chart
   if(m_is_visible)
     {
      UpdateDashboardUI();
     }
          
   // 1. Manage open positions (Breakeven and Trailing)
   if(!blWasTest)
   {
      InpStopLoss          = MathFloor(SymbolInfoDouble(_Symbol,SYMBOL_BID)*InpStopLossCoeff);
      InpTrailTrigger      = MathFloor(SymbolInfoDouble(_Symbol,SYMBOL_BID)*InpTrailTrigCoeff);
      InpTrailDistance     = MathFloor(SymbolInfoDouble(_Symbol,SYMBOL_BID)*InpTrailDistCoeff);
      InpTrailStep         = MathFloor(SymbolInfoDouble(_Symbol,SYMBOL_BID)*InpTrailStepCoeff);
      InpMinDistancePoints = MathFloor(SymbolInfoDouble(_Symbol,SYMBOL_BID)*InpMinDistCoeff);   
   }
   
   
   if(blWasTest==false&&TimeCurrent()-inittime>1000000&&blWasTrade==false)
   {   
      tfAnalizeTimeframe=PERIOD_CURRENT;
      tfAtrTimeframe=PERIOD_CURRENT;
      tfTimeframe=PERIOD_CURRENT;           
      InpIndentPoints=100; 
      InpMinDistancePoints=100;
      blWasTest=true;
   }
        
   
   ManagePositions();
      
   // 2. Check time filter
   if(InpUseTimeFilter && (!IsTimeToTrade()||!IsDayToTrade()||IsNWTime()))
   {
      if(InpCloseOnTimeOut)
      {
         PurgeMarket();
      }
      return; 
   }


   // Search algorithm executes once when a new bar opens
   datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, tfAnalizeTimeframe, SERIES_LASTBAR_DATE);
   if(currentBarTime == lastBarTime) return; 
   
   
   
   // If we already have OPEN POSITIONS, do not place new orders and do not move old ones
   if(PositionsTotal() > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(!blWasTest)return; // Position active, exit
         }
      }
   }

   // 3. Search for High and Low over N bars
   double highPrices[], lowPrices[];
   ArraySetAsSeries(highPrices, true);
   ArraySetAsSeries(lowPrices, true);
   
   if(CopyHigh(_Symbol, tfTimeframe, StartBarToAnalyze, InpBarsToAnalyze, highPrices) < InpBarsToAnalyze ||
      CopyLow(_Symbol, tfTimeframe, StartBarToAnalyze, InpBarsToAnalyze, lowPrices) < InpBarsToAnalyze)
   {
      //Print("Error copying price data.");
      if(!blWasTest)return;
   }
   
   int maxIdx = ArrayMaximum(highPrices);
   int minIdx = ArrayMinimum(lowPrices);
   
   double highestPrice = highPrices[maxIdx];
   double lowestPrice  = lowPrices[minIdx];
   
   // Get current market prices
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // 4. CHECK: Are the extremes at a sufficient distance from the current price
   double distToHigh = (highestPrice - ask) / point;
   double distToLow  = (bid - lowestPrice) / point;
   
   if(distToHigh < InpMinDistancePoints || distToLow < InpMinDistancePoints)
   {
      Print("Extremes too close to price. Order actions skipped. To High: ", 
            NormalizeDouble(distToHigh, 1), " p., To Low: ", NormalizeDouble(distToLow, 1), " p.");
      lastBarTime = currentBarTime;
      if(!blWasTest)return; 
   }
   
   
   if(GetSpread()>InpMaxSpread)
   {
      Print("Spread high!");
      lastBarTime = currentBarTime;
      if(!blWasTest)return; 
   }
   
   // 5. Calculate target levels for orders
   double targetBuyStopPrice  = NormalizeDouble(highestPrice - (InpIndentPoints * point), _Digits);
   double targetSellStopPrice = NormalizeDouble(lowestPrice + (InpIndentPoints * point), _Digits);
   
   double buySL = (InpStopLoss > 0)   ? NormalizeDouble(targetBuyStopPrice - InpStopLoss * point, _Digits) : 0;
   
   double sellSL = (InpStopLoss > 0)   ? NormalizeDouble(targetSellStopPrice + InpStopLoss * point, _Digits) : 0;
   
   // Variables for tracking existing orders in the book
   ulong buyTicket = 0;
   ulong sellTicket = 0;
   double currentBuyPrice = 0;
   double currentSellPrice = 0;
   
   // Check the order book for our old "active" pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
      {
         long type = OrderGetInteger(ORDER_TYPE);
         if(type == ORDER_TYPE_BUY_STOP)
         {
            buyTicket = ticket;
            currentBuyPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         }
         else if(type == ORDER_TYPE_SELL_STOP)
         {
            sellTicket = ticket;
            currentSellPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         }
      }
   }
   
   int curdirection=GetCurrentHTFDirection(InpDirection);
   
   // 6. Placing new or MOVING existing orders
   // Get current prices and broker Stop Level
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   // Set the minimum allowable offset from the market in points (Stop Level + buffer)
   int minDistancePoints = stopLevel;
   
   if(minDistancePoints < 5) minDistancePoints = 5; // Protection against zero Stop Level
   // BUY_STOP handling
   
   if(buyTicket > 0) // If order already exists in the book
   {
      // If the old order price does not match the new calculated price - move it
      if(NormalizeDouble(currentBuyPrice, _Digits) != NormalizeDouble(targetBuyStopPrice,_Digits))
      {
         if(MathAbs(targetBuyStopPrice-currentBuyPrice)>minDistancePoints)
         if(trade.OrderModify(buyTicket, NormalizeDouble(targetBuyStopPrice,_Digits), NormalizeDouble(buySL,_Digits), 0, ORDER_TIME_GTC, 0))
            Print("BuyStop order #", buyTicket, " SUCCESSFULLY MOVED to new level: ", targetBuyStopPrice);
         else
            Print("Error moving BuyStop #", buyTicket, ": ", trade.ResultRetcodeDescription());
      }
   }
   else // If no order in the book - place from scratch
   {
      double tradeLot=0;
      if(InpLotSize==0)
      {
        tradeLot = CalculateLotSize(InpStopLoss);        
      }
      else tradeLot=InpLotSize; 
      tradeLot=NormalizeDouble(tradeLot,2);
      if(targetBuyStopPrice >= ask + minDistancePoints * point)
      {
         if(CheckVolumeValue(tradeLot,voldiscrip)&&CheckMoneyForTrade(_Symbol,tradeLot,ORDER_TYPE_BUY_STOP))
         {  
            blWasTrade=true;        
            if(curdirection==1 || curdirection==2)
               if(trade.BuyStop(tradeLot, targetBuyStopPrice, _Symbol, buySL, 0, ORDER_TIME_GTC))
               {
                  Print("Placed new BuyStop at level: ", targetBuyStopPrice);
                  blWasTrade=true;
               }
               
         
            if(curdirection==0 && InpNoDirecTrade) 
            if(trade.BuyStop(tradeLot, targetBuyStopPrice, _Symbol, buySL, 0, ORDER_TIME_GTC))
               Print("Placed new BuyStop at level: ", targetBuyStopPrice);  
         }
      }          
   }
   
  
   
   // SELL_STOP handling
   if(sellTicket > 0) // If order already exists in the book
   {
      // If the old order price does not match the new calculated price - move it
      if(NormalizeDouble(currentSellPrice, _Digits) != NormalizeDouble(targetSellStopPrice,_Digits))
      {
         blWasTrade=true; 
         if(MathAbs(targetBuyStopPrice-currentBuyPrice)>minDistancePoints)
         if(trade.OrderModify(sellTicket, NormalizeDouble(targetSellStopPrice,_Digits), NormalizeDouble(sellSL,_Digits), 0, ORDER_TIME_GTC, 0))
            Print("SellStop order #", sellTicket, " SUCCESSFULLY MOVED to new level: ", targetSellStopPrice);
         else
            Print("Error moving SellStop #", sellTicket, ": ", trade.ResultRetcodeDescription());
      }
   }
   else // If no order in the book - place from scratch
   {
      double tradeLot=0;
      if(InpLotSize==0)
      {
        tradeLot = CalculateLotSize(InpStopLoss);        
      }
      else tradeLot=InpLotSize; 
      tradeLot=NormalizeDouble(tradeLot,2); 
      if(targetSellStopPrice <= bid - minDistancePoints * point)
      {
         if(CheckVolumeValue(tradeLot,voldiscrip)&&CheckMoneyForTrade(_Symbol,tradeLot,ORDER_TYPE_SELL_STOP))
         {
            if(curdirection==-1 || curdirection==2) 
            if(trade.SellStop(tradeLot, targetSellStopPrice, _Symbol, sellSL, 0, ORDER_TIME_GTC))
               Print("Placed new SellStop at level: ", targetSellStopPrice);
         
            if(curdirection==0 && InpNoDirecTrade) 
            if(trade.SellStop(tradeLot, targetSellStopPrice, _Symbol, sellSL, 0, ORDER_TIME_GTC))
            {                             
               Print("Placed new SellStop at level: ", targetSellStopPrice);              
               blWasTrade=true;           
            }
               
         }
      }
   }   
   ManagePositions();
   lastBarTime = currentBarTime;
}

//+------------------------------------------------------------------+
//| Function to check time range                                     |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt); 
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes   = InpStartHour * 60 + InpStartMinute;
   int endMinutes     = InpEndHour * 60 + InpEndMinute;
   

   if(startMinutes <= endMinutes)
      {
         return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
      }
   else 
      {
         return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
      }

}

bool IsNWTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt); 
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes   = InpNWStartHour * 60 + InpNWStartMinute;
   int endMinutes     = InpNWEndHour * 60 + InpNWEndMinute;   
   
   if(startMinutes <= endMinutes)
      {
         return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
      }
   else 
      {
         return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
      }
}   

//+------------------------------------------------------------------+
//| Function to check days of the week                               |
//+------------------------------------------------------------------+
bool IsDayToTrade()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt); 
   
   if(dt.day_of_week==1&&!InpTradeMonday) return false;
   if(dt.day_of_week==2&&!InpTradeTuesday) return false; 
   if(dt.day_of_week==3&&!InpTradeWednesday) return false;
   if(dt.day_of_week==4&&!InpTradeThursday) return false; 
   if(dt.day_of_week==5&&!InpTradeFriday) return false;   
 
   return true;
     
}

//+------------------------------------------------------------------+
//| Function to completely delete orders and close positions on timeout |
//+------------------------------------------------------------------+
void PurgeMarket()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
      {
         trade.OrderDelete(ticket);
         //Print("Deleted pending order #", ticket, " after trading hours.");
      }
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);trade.PositionClose(ticket);
         //Print("Closed active position #", ticket, " after trading hours.");
      }
   }
}
//+------------------------------------------------------------------+
//|   Position management: Breakeven and Trailing Stop               |
//+------------------------------------------------------------------+

// Add this variable to the input parameters at the beginning of the EA if it doesn't exist


void ManagePositions()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Get the minimum allowable distance from the market in points (Stop Level)
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   // Just in case, set a filter if Stop Level is 0
   if(stopLevel < 5) stopLevel = 5; 

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong  ticket     = PositionGetInteger(POSITION_TICKET);
         double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL  = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         double currentTP  = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         long   posType    = PositionGetInteger(POSITION_TYPE);
         
         int currentIndent = CalculateAtrIndentPoints();
         if(currentIndent < 10) currentIndent = 10;
         
         double targetSL = currentSL; 

         if(posType == POSITION_TYPE_BUY)
         {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // 1. Breakeven for BUY
            if(InpUseBreakeven && (currentSL < openPrice))
            {
               if(bid - openPrice >= InpBreakevenTrigger * point)
               {
                  targetSL = NormalizeDouble(openPrice + InpBreakevenProfit * point, _Digits);
               }
            }
            
            // 2. Trailing stop for BUY
            if(InpUseTrailing && targetSL == currentSL)
            {
               if(bid - openPrice >= InpTrailTrigger * point)
               {
                  double newSL = NormalizeDouble(bid - currentIndent * currentIndentCoef * point, _Digits);
                  if(newSL > currentSL + currentIndent * point || currentSL == 0)
                  {
                     targetSL = newSL;
                  }
               }
            }
            
            // --- CHECKS FOR BUY ---
            if(targetSL != currentSL)
            {
               // Check offset from old price (only if SL was already set)
               if(currentSL > 0 && MathAbs(targetSL - currentSL) < InpMinStepPoints * point)
               {
                  targetSL = currentSL; // Cancel: change too small
               }
               // Check distance to current market price (Bid)
               else if(bid - targetSL < stopLevel * point)
               {
                  targetSL = currentSL; // Cancel: too close to market
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            // 1. Breakeven for SELL
            if(InpUseBreakeven && (currentSL > openPrice || currentSL == 0))
            {
               if(openPrice - ask >= InpBreakevenTrigger * point)
               {
                  targetSL = NormalizeDouble(openPrice - InpBreakevenProfit * point, _Digits);
               }
            }
            
            // 2. Trailing stop for SELL
            if(InpUseTrailing && targetSL == currentSL)
            {  
               if(openPrice - ask >= InpTrailTrigger * point)
               {
                  double newSL = NormalizeDouble(ask + currentIndent * currentIndentCoef * point, _Digits);
                  if(newSL < currentSL - currentIndent * point || currentSL == 0)
                  {
                     targetSL = newSL;
                  }
               }
            }
            
            // --- CHECKS FOR SELL ---
            if(targetSL != currentSL)
            {
               // Check offset from old price (only if SL was already set)
               if(currentSL > 0 && MathAbs(targetSL - currentSL) < InpMinStepPoints * point)
               {
                  targetSL = currentSL; // Cancel: change too small
               }
               // Check distance to current market price (Ask)
               else if(targetSL - ask < stopLevel * point)
               {
                  targetSL = currentSL; // Cancel: too close to market
               }
            }
         }

         // Send order if all filters are passed
         if(targetSL != currentSL)
         {
            targetSL = NormalizeDouble(targetSL, _Digits);
            if(trade.PositionModify(ticket, NormalizeDouble(targetSL,_Digits), NormalizeDouble(currentTP,_Digits)))
            {
               Print("Position #", ticket, " modified. New SL: ", targetSL);
            }
         }
      }
   }
}



double CalculateLotSize(double stopLossPoints)
{
   // 1. Get current equity
   double equity = stats.current_balance;
   
   // 2. Calculate the amount in deposit currency we are risking
   double riskAmount = equity * (InpRiskPercent / 100.0);
   
   // If stop loss is not set in main settings, use default for risk calculation
   double sl = (stopLossPoints > 0) ? stopLossPoints : InpDefaultStopLoss;
   
   // 3. Get tick value for minimum lot (VOLUME_MIN)
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue <= 0 || point <= 0) return 0.0;
   
   // Adjust point value if TickSize differs from Point
   double pointValue = (tickValue / tickSize) * point;
   
   // 4. Calculate theoretical lot size
   double calculatedLot = riskAmount / (sl * pointValue);

   // 5. Limit lot according to broker requirements
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Round lot to the nearest step (e.g., to 0.01)
   calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep * 0.1;
   
   // Check min/max boundaries
   if(calculatedLot < minLot) calculatedLot = minLot;
   if(calculatedLot > maxLot) calculatedLot = maxLot;
   if(calculatedLot==0)calculatedLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   return NormalizeDouble(calculatedLot, 2);
}


int GetCurrentHTFDirection(Direction direc)
{
    // Get opening price and current price (Bid)
    double dOpen = iOpen(_Symbol, PERIOD_D1, 0);
    double wOpen = iOpen(_Symbol, PERIOD_W1, 0);
    double mOpen = iOpen(_Symbol, PERIOD_MN1, 0);
    double h12Open = iOpen(_Symbol, PERIOD_H12, 0);
    double h6Open = iOpen(_Symbol, PERIOD_H6, 0);
    double h4Open = iOpen(_Symbol, PERIOD_H4, 0);
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
    // Check for correct historical data and price
    if(dOpen <= 0 || wOpen <= 0 || mOpen <= 0 || h12Open <= 0 || h6Open <= 0 || h4Open <= 0 || currentPrice <= 0) return 0;

    // Determine daily direction (D1)
    int dailyDir = 0;
    if(currentPrice > dOpen) dailyDir = 1;
    else if(currentPrice < dOpen) dailyDir = -1;

    // Determine weekly direction (W1)
    int weeklyDir = 0;
    if(currentPrice > wOpen) weeklyDir = 1;
    else if(currentPrice < wOpen) weeklyDir = -1;

    // Determine monthly direction (MN1)
    int monthDir = 0;
    if(currentPrice > mOpen) monthDir = 1;
    else if(currentPrice < mOpen) monthDir = -1;

    // Determine H12 direction (H12)
    int h12Dir = 0;
    if(currentPrice > h12Open) h12Dir = 1;
    else if(currentPrice < h12Open) h12Dir = -1;  

    // Determine H6 direction (H6)
    int h6Dir = 0;
    if(currentPrice > h6Open) h6Dir = 1;
    else if(currentPrice < h6Open) h6Dir = -1;  

    // Determine H4 direction (H4)
    int h4Dir = 0;
    if(currentPrice > h4Open) h4Dir = 1;
    else if(currentPrice < h4Open) h4Dir = -1; 
    
    // Choose calculation option based on parameter
    switch(direc)
    {
       case Direction_None:
          return 2;  
       
       case Direction_H4:
          return h4Dir;
         
       case Direction_H6:
          return h6Dir;
    
       case Direction_H12:
          return h12Dir;
    
       case Direction_Month:
          return monthDir;
          
       case Direction_Week:
          return weeklyDir;
          
       case Direction_Day:
          return dailyDir;
          
       case Direction_MonthWeek:
          if(monthDir == 1  && weeklyDir == 1)  return 1;
          if(monthDir == -1 && weeklyDir == -1) return -1;
          break;
          
       case Direction_MonthDay:
          if(monthDir == 1  && dailyDir == 1)  return 1;
          if(monthDir == -1 && dailyDir == -1) return -1;
          break;
          
       case Direction_WeekDay:
          if(weeklyDir == 1  && dailyDir == 1)  return 1;
          if(weeklyDir == -1 && dailyDir == -1) return -1;
          break;
          
       case Direction_MonthWeekDay:
          if(monthDir == 1  && weeklyDir == 1  && dailyDir == 1)  return 1;
          if(monthDir == -1 && weeklyDir == -1 && dailyDir == -1) return -1;
          break;
       
       
       case Direction_MonthDayH4:
          if(monthDir == 1  && dailyDir == 1  && h4Dir == 1)  return 1;
          if(monthDir == -1 && dailyDir == -1 && h4Dir == -1) return -1;
          break;   
       
       case Direction_WeekH12:
       if(weeklyDir == 1  && h12Dir == 1)  return 1;
       if(weeklyDir == -1 && h12Dir == -1) return -1;
       
       case Direction_MonthH12:
       if(monthDir == 1  && h12Dir == 1)  return 1;
       if(monthDir == -1 && h12Dir == -1) return -1;
       
       case Direction_DayH12:
       if(dailyDir == 1  && h12Dir == 1)  return 1;
       if(dailyDir == -1 && h12Dir == -1) return -1;
       
       case Direction_WeekH6:
       if(weeklyDir == 1  && h6Dir == 1)  return 1;
       if(weeklyDir == -1 && h6Dir == -1) return -1;
       
       case Direction_MonthH6:
       if(monthDir == 1  && h6Dir == 1)  return 1;
       if(monthDir == -1 && h6Dir == -1) return -1;
       
       case Direction_DayH6:
       if(dailyDir == 1  && h6Dir == 1)  return 1;
       if(dailyDir == -1 && h6Dir == -1) return -1;
       
       case Direction_WeekH4:
       if(weeklyDir == 1  && h4Dir == 1)  return 1;
       if(weeklyDir == -1 && h4Dir == -1) return -1;
       
       case Direction_MonthH4:
       if(monthDir == 1  && h4Dir == 1)  return 1;
       if(monthDir == -1 && h4Dir == -1) return -1;
       
       case Direction_DayH4:
       if(dailyDir == 1  && h4Dir == 1)  return 1;
       if(dailyDir == -1 && h4Dir == -1) return -1;
       
       break;
    }

    // If combination conditions are not met (multi-directional movement)
    return 0;
}


//+------------------------------------------------------------------+
//| Function to update panel UI                                      |
//+------------------------------------------------------------------+
void UpdateDashboardUI()
  {
   string currency = AccountInfoString(ACCOUNT_CURRENCY);

   // 1. Update the new current balance field
   UpdateLabelText("DB_Val_CurrBal", StringFormat("%.2f %s", stats.current_balance, currency));
   
   // 2. Update spread
   UpdateLabelText("DB_Val_Spread", StringFormat("%d", GetSpread(), ""));
   
   // 3. Update number of winning and losing trades
   UpdateLabelText("DB_Val_Deals", StringFormat("%d / %d", stats.deals_win, stats.deals_loss));
   
   // 4. Update current result and change its color (green/red)
   UpdateLabelText("DB_Val_Result", StringFormat("%.2f %s", stats.total_profit, currency));
   ObjectSetInteger(0, "DB_Val_Result", OBJPROP_COLOR, (stats.total_profit >= 0) ? COLOR_PROFIT : COLOR_LOSS);
   
   // 5. Update maximum historical result
   UpdateLabelText("DB_Val_Max", StringFormat("%.2f %s", stats.max_profit, currency));
   
   // 6. Update drawdown from maximum and highlight in red if greater than zero
   UpdateLabelText("DB_Val_DD", StringFormat("%.2f %s", stats.current_drawdown, currency));
   ObjectSetInteger(0, "DB_Val_DD", OBJPROP_COLOR, (stats.current_drawdown > 0) ? COLOR_LOSS : TEXT_MUTED);

   // Redraw the chart for instant display of changes
   ChartRedraw(0);
  }



//+------------------------------------------------------------------+
//| Function to create panel geometry (Opaque + English)             |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   // Basic size settings
   int x_base1 = 20;  // Left indent for FIRST panel (with metrics)
   int y_base  = 40;  // Top indent for both panels
   int width   = 320; // Width of each panel
   int height  = 234; // Height of each panel
   int gap     = 10;  // Distance between panels
   
   int x_base2 = x_base1 + width + gap; // Left indent for SECOND panel (with image)

   // Path to resource inside EX5
   string background_png = "::Images\\mr_blade.bmp"; 

   // ==========================================
   // PANEL 1: OPAQUE WITH METRICS (LEFT)
   // ==========================================
   // Solid opaque background for metrics panel
   string bg_solid = "DB_Bg_Solid";
   CreateRectLabel(bg_solid, x_base1, y_base, width, height, BG_COLOR, BORDER_COLOR, 1);
   ObjectSetInteger(0, bg_solid, OBJPROP_BACK, false); 

   // Expert name (Header on metrics panel)
   CreateLabel("DB_Title", x_base1 + 15, y_base + 15, MQLInfoString(MQL_PROGRAM_NAME), TEXT_MAIN, 12, true);
   
   // Separator line on metrics panel
   CreateRectLabel("DB_Line", x_base1 + 15, y_base + 47, width - 30, 1, BORDER_COLOR, BORDER_COLOR, 0);

   // Static labels
   int start_y = y_base + 50;
   int row_height = 22;

   CreateLabel("DB_Lbl_Magic",   x_base1 + 15, start_y,                 "EA Magic Number:", TEXT_MUTED, 9, false); 
   CreateLabel("DB_Lbl_InitBal", x_base1 + 15, start_y + row_height,    "Initial Balance:", TEXT_MUTED, 9, false);   
   CreateLabel("DB_Lbl_Deals",   x_base1 + 15, start_y + row_height*2,  "Trades (Win/Loss):", TEXT_MUTED, 9, false);
   CreateLabel("DB_Lbl_Result",  x_base1 + 15, start_y + row_height*3,  "Current Profit:", TEXT_MUTED, 9, false);
   CreateLabel("DB_Lbl_Max",     x_base1 + 15, start_y + row_height*4,  "Max Profit:", TEXT_MUTED, 9, false);
   CreateLabel("DB_Lbl_DD",      x_base1 + 15, start_y + row_height*5,  "Current Drawdown:", TEXT_MUTED, 9, false);   
   CreateLabel("DB_Lbl_Spread",  x_base1 + 15, start_y + row_height*6,  "Spread:", TEXT_MUTED, 9, false);
   CreateLabel("DB_Lbl_CurrBal", x_base1 + 15, start_y + row_height*7,  "Current Balance:", TEXT_MUTED, 10, false);
   
   // Dynamic labels (Data values)
   int x_value = x_base1 + width - 15;
   
   string init_bal_text = StringFormat("%.2f %s", InpInitBalance, AccountInfoString(ACCOUNT_CURRENCY));
   string magic_text = StringFormat("%d", InpMagicNumber, "");
   
   CreateValueLabel("DB_Val_Magic",   x_value, start_y,                 magic_text, TEXT_MAIN, 9, true);
   CreateValueLabel("DB_Val_InitBal", x_value, start_y + row_height,    init_bal_text, TEXT_MAIN, 9, true);
   CreateValueLabel("DB_Val_Deals",   x_value, start_y + row_height*2,  "- / -", TEXT_MAIN, 9, true);
   CreateValueLabel("DB_Val_Result",  x_value, start_y + row_height*3,  "0.00",  COLOR_PROFIT, 9, true);
   CreateValueLabel("DB_Val_Max",     x_value, start_y + row_height*4,  "0.00",  TEXT_MAIN, 9, true);
   CreateValueLabel("DB_Val_DD",      x_value, start_y + row_height*5,  "0.00",  TEXT_MUTED, 9, true);
   CreateValueLabel("DB_Val_Spread",  x_value, start_y + row_height*6,  "0",  TEXT_MAIN, 9, true);
   CreateValueLabel("DB_Val_CurrBal", x_value, start_y + row_height*7,  "0.00",  TEXT_MAIN, 10, true);

   // ==========================================
   // PANEL 2: TRANSPARENT WITH IMAGE (RIGHT)
   // ==========================================
   string bg_pic = "DB_Bg_Pic";
   ObjectDelete(0, bg_pic); 
   if(ObjectCreate(0, bg_pic, OBJ_BITMAP_LABEL, 0, 0, 0))
     {
      ObjectSetInteger(0, bg_pic, OBJPROP_XDISTANCE, x_base2);
      ObjectSetInteger(0, bg_pic, OBJPROP_YDISTANCE, y_base);
      ObjectSetString(0, bg_pic, OBJPROP_BMPFILE, 0, background_png); 
      ObjectSetInteger(0, bg_solid, OBJPROP_BACK, false);   
      ObjectSetInteger(0, bg_pic, OBJPROP_BACK, true);               
      ObjectSetInteger(0, bg_pic, OBJPROP_SELECTABLE, false);         
      ObjectSetInteger(0, bg_pic, OBJPROP_HIDDEN, true);
                
     }
   
   ChartRedraw(0); 
  }






//+------------------------------------------------------------------+
//| Helper functions for creating UI objects                         |
//+------------------------------------------------------------------+
void CreateRectLabel(string name, int x, int y, int w, int h, color bg, color border, int border_width)
  {
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void CreateLabel(string name, int x, int y, string text, color clr, int font_size, bool is_bold)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, FONT_NAME);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void CreateValueLabel(string name, int x, int y, string text, color clr, int font_size, bool is_bold)
  {
   CreateLabel(name, x, y, text, clr, font_size, is_bold);
   // Change anchor to top-right for right-aligned column
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
  }

void UpdateLabelText(string name, string text)
  {
  ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
//| Function to calculate metrics from history for a specific Magic Number |
//+------------------------------------------------------------------+
void CalculateExpertStats(long magic_number)
  {
   // Reset all structure values before calculation
   stats.total_profit     = 0.0;
   stats.max_profit       = 0.0;
   stats.current_drawdown = 0.0;
   stats.deals_win        = 0;
   stats.deals_loss       = 0;
   
   double current_peak = 0.0;

   // Request trade history
   if(HistorySelect(0, TimeCurrent()))
     {
      int deals_total = HistoryDealsTotal();

      for(int i = 0; i < deals_total; i++)
        {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket > 0)
           {
            // Filter by Magic Number
            if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == magic_number)
              {
               // Skip balance operations, count only trading deals
               long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
               if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) 
                  continue;

               double profit     = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
               double swap       = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
               double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
               
               double net_deal_profit = profit + swap + commission;

               // Count number of trades
               if(net_deal_profit > 0)       stats.deals_win++;
               else if(net_deal_profit < 0)  stats.deals_loss++;

               // Cumulative total
               stats.total_profit += net_deal_profit;

               // Record peak for local drawdown calculation
               if(stats.total_profit > current_peak)
                 {
                  current_peak = stats.total_profit;
                 }
               
               // Historical maximum profit
               if(stats.total_profit > stats.max_profit)
                 {
                  stats.max_profit = stats.total_profit;
                 }
              }
           }
        }
      
      // Calculate current drawdown from historical maximum
      stats.current_drawdown = stats.max_profit - stats.total_profit;
      if(stats.current_drawdown < 0) stats.current_drawdown = 0.0;
     }
   else
     {
      Print("Error loading history in CalculateExpertStats: ", GetLastError());
     }
   
   // Round monetary values for accuracy
   stats.total_profit     = NormalizeDouble(stats.total_profit, 2);
   stats.max_profit       = NormalizeDouble(stats.max_profit, 2);
   stats.current_drawdown = NormalizeDouble(stats.current_drawdown, 2);
   stats.init_balance = InpInitBalance;
   stats.current_balance = NormalizeDouble(stats.init_balance + stats.total_profit,2);
  }

//+------------------------------------------------------------------+
//| Calculates dynamic indent in points based on ATR volatility      |
//+------------------------------------------------------------------+
int CalculateAtrIndentPoints()
{
   // Array for copying ATR value
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   // Copy the last closed bar value (index 1) to avoid data flickering
   if(CopyBuffer(atrHandle, 0, 1, 1, atrValues) < 1)
     {
      // If data could not be copied, return default fixed indent
      Print("Warning: Failed to copy ATR data. Using standard indent.");
      return InpIndentPoints;
     }
     
   double atrValue = atrValues[0];
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT); 
   
   if(point <= 0 || atrValue <= 0) return InpIndentPoints; 
   
   // Calculate indent: (ATR Value * Coefficient) / Point size
   double indentPointsDouble = (atrValue * InpATRCoeff) / point;
   
   // Round to nearest whole number of points
   int dynamicIndent = (int)MathRound(indentPointsDouble);
   
   // Set minimum threshold (e.g., indent should not be less than 2 points)
   if(dynamicIndent < 2) dynamicIndent = 2;
   
   return dynamicIndent;
}

double GetATRValue()
{
   // Array for copying ATR value
   double atrValues[];
   ArraySetAsSeries(atrValues, true);   
   // Copy the last closed bar value (index 1) to avoid data flickering
   if(CopyBuffer(atrHandle, 0, 0, 2, atrValues) < 1)return 0;    
   return atrValues[0];
}




int GetSpread()
{
   double Ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double Bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double spred=(Ask-Bid)*100;
   
   return spred;
   
}

bool CheckVolumeValue(double volume,string &description)
{
//--- minimum allowable volume for trading operations
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
      description=StringFormat("Volume is less than the minimum allowable SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }

//--- maximum allowable volume for trading operations
   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      description=StringFormat("Volume is greater than the maximum allowable SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }

//--- get the minimum volume gradation
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      description=StringFormat("Volume is not a multiple of the minimum gradation SYMBOL_VOLUME_STEP=%.2f, nearest correct volume %.2f",
                               volume_step,ratio*volume_step);
      return(false);
     }
   description="Correct volume value";
   return(true);
}


bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
//--- get opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
//--- required and free margin values
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   //--- call the check function
   if(!OrderCalcMargin(type,symb,lots,price,margin))
     {
      //--- something went wrong, report and return false
      Print("Error in ",__FUNCTION__," code=",GetLastError());
      return(false);
     }
   //--- if there are insufficient funds for the operation
   if(margin>free_margin)
     {
      //--- report the error and return false
      Print("Not enough money for ",EnumToString(type)," ",lots," ",symb," Error code=",GetLastError());
      return(false);
     }
//--- check passed successfully
   return(true);
  }