//+------------------------------------------------------------------+
//|                                                 LotCul_MT4.mq4 |
//|                                 　　　　　　　　　　　　　　　　　　 |
//|                                             　　　　　　　　　　 |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <stdlib.mqh> // ErrorDescriptionのため追加
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>   // CEdit クラスのために追加
#include <Controls\Label.mqh>  // CLabel クラスのために追加
#include <Controls\CheckBox.mqh> // CCheckBox クラスのために追加

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
// --- UI Controls ---
CDialog UIPanel;
CAppDialog appDialog; // CAppDialog インスタンスを追加
// CButton Button; // This was a generic button, specific buttons are defined below

// JLC.mq5 から移植するUI要素
//-buy sell Button-
CButton buySellButton; // Buy/Sell切り替えボタンを追加
bool isBuyMode = true; // 現在のモード (true: Buy, false: Sell) を保持する変数を追加
//-market or limit button-
CButton marketLimitButton; // 成り行き/指値切り替えボタンを追加
bool isMarketOrder = true; // 現在の注文タイプ (true: 成り行き, false: 指値) を保持する変数を追加
//-entry Price-
CLabel entryPriceLabel;      // "Entry Price:" ラベル用
CEdit entryPriceEdit;        // 価格入力欄用
CLabel EntryKeyLabel;     // キーショートカットラベル
double entryPriceValue = 0.0; // 入力されたエントリー価格を保持する変数
//-entry Price +- buttons-
CButton entryPricePlusButton; // 価格 +1 point ボタン
CButton entryPriceMinusButton; // 価格 -1 point ボタン
//-Stop Loss-
CLabel slLabel;          // "SL Price:" ラベル
CEdit slEdit;            // SL価格入力欄
CLabel StopKeyLabel;     // キーショートカットラベル
double slValue ;     // 入力されたSL価格
CButton slPlusButton;    // SL価格 +1 point ボタン
CButton slMinusButton;   // SL価格 -1 point ボタン
//-Take Profit-
CLabel tpLabel;          // "TP Price:" ラベル
CEdit tpEdit;            // TP価格入力欄
CLabel ProfitKeyLabel;     // キーショートカットラベル
double tpValue = 0.0;     // 入力されたTP価格
CButton tpPlusButton;    // TP価格 +1 point ボタン
CButton tpMinusButton;   // TP価格 -1 point ボタン
//- risk Percent-
CLabel riskPercentLabel; //許容損失％ "risk %"ラベル
CEdit riskPercentEdit; //許容損失％入力欄
double RiskPercent = 1.00; //許容リスク％値
//- Cul Lot--
CLabel CulLotLabel; // "Lot"
CEdit CulLotEdit; // Lot 入力・表示欄
double CulLotValue = 0.0; //ロットを保持する変数
//- Risk $--
CLabel RiskUSDLabel; // ラベル "Risk $" リスクを通貨で表現
CEdit RiskUSDEdit; // Edit  "Risk $" リスクを通貨で表現
double RiskUSDValue; //　損切幅と、Risk%　→　ロットから計算される損失金額　を　保持する変数
//- Order Button--
CButton OrderButton; //発注ボタン
CLabel OrderKeyLabel; //キーショートカットラベル
//- Confirm --
CLabel ConfirmCheckBoxLabel; //チェックボックスのラベル
CCheckBox ConfirmCheckBox ; //発注前の確認表示をするかしないか
//- Lines Toggle Button --
CButton linesToggleButton;  // ライン表示切り替えボタン
bool    g_showLines = true; // ライン表示状態 (true: 表示, false: 非表示)

// --- JLC.mq5 から移植するその他のグローバル変数 ---
input int MAGIC_NUMBER = 20240725; // マジックナンバー

// --- マウスカーソル位置保存用 ---
long   g_mouse_last_x = 0;
long   g_mouse_last_y = 0;
int    g_mouse_last_subwindow = -1;
string g_draggingLineName = ""; // ドラッグ中のライン名

// --- ラインオブジェクト名 ---
string entryPriceLineName = "LotCul_EntryLine_MT4";
string slLineName = "LotCul_SlLine_MT4";
string tpLineName = "LotCul_TpLine_MT4";

// --- ライン情報ラベル名 ---
string etInfoLabelName = "LotCul_EtInfoLabel_MT4";
string slInfoLabelName = "LotCul_SlInfoLabel_MT4";
string tpInfoLabelName = "LotCul_TpInfoLabel_MT4";


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//-- チャートのプロパティを設定 --
   ChartSetInteger(0, CHART_FOREGROUND, false); // チャートを最前面に表示しないように設定
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); // マウス移動イベントを有効にする
// ChartSetInteger(0, CHART_EVENT_KEY_DOWN, true); // MQL4ではこの行は不要な場合が多く、OnChartEventでCHARTEVENT_KEYDOWNをハンドルする

//--- SLの初期値 数値を現在価格とずらして表示させとく、かぶると見にくいから。
   slValue = NormalizeDouble(MarketInfo(Symbol(), MODE_ASK) - (MarketInfo(Symbol(), MODE_POINT) * 30), Digits());
// tpValue の初期値も設定 (例: Ask + 30 pips)
   tpValue = NormalizeDouble(MarketInfo(Symbol(), MODE_ASK) + (MarketInfo(Symbol(), MODE_POINT) * 30), Digits());


//-- UI
////// MQL4は5と違ってAppDialogを使う。//////
// appDialog を初期化（UIPanel と同じ位置・サイズで作成）
   if(!appDialog.Create(0, "LotCul", 0, 50, 50, 250, 400))
     {
      Print("Failed to create app dialog. Error: ", GetLastError());
      return(INIT_FAILED);
     }
   appDialog.Visible(false); // 初期状態で非表示にする　mql4では、親DialogにDialogを追加してRunして使うが、親は非表示。厄介な仕様

// ダイアログの作成 (位置:100,100 サイズ:300x200)
   if(!UIPanel.Create(0, "LotCulPanel", 0, 0, 0, 200, 345)) // appDialog内の相対位置で作成 // Y2を調整
     {
      Print("Failed to create dialog. Error: ", GetLastError());
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   UIPanel.Caption("Lot Calculator");  // タイトルを設定
   if(!appDialog.Add(UIPanel))
     {
      Print("UIPanel の追加に失敗しました。Error: ", GetLastError());
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- Buy/Sell 切り替えボタンの作成 ---
   if(!buySellButton.Create(0, "BuySellButton", 0, 15, 15, 85, 40))
     {
      Print("ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   buySellButton.Text("Buy");
   if(!UIPanel.Add(buySellButton))
     {
      Print("ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- 成り行き/指値 切り替えボタンの作成 ---
   if(!marketLimitButton.Create(0, "MarketLimitButton", 0, 95, 15, 165, 40))
     {
      Print("成り行き/指値ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   marketLimitButton.Text("Market");
   if(!UIPanel.Add(marketLimitButton))
     {
      Print("成り行き/指値ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//基準　XY
   int EditLabelX = 5;
   int EditLabelY = 50;
   int EditLabelDistance = 35; //ラベル間のY距離
   int EditBoxX1 = 75;
   int EditBoxY1 = 48; //EditBoxのY1
   int EditBoxX2 = 168; //EditBoxのX2
   int EditBoxY2 = 72; //EditBoxのY2
   int EditBoxDistance = 35; //EditBox間のY距離

//--- Entry Price ラベルの作成 ---
   if(!entryPriceLabel.Create(0, "EntryPriceLabel", 0, EditLabelX, EditLabelY, 0, 0))
     {
      Print("Entry Price ラベルの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   entryPriceLabel.Text("Entry Price:");
   if(!UIPanel.Add(entryPriceLabel))
     {
      Print("Entry Price ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- Entry Price 編集ボックスの作成 ---
   if(!entryPriceEdit.Create(0, "EntryPriceEdit", 0, EditBoxX1, EditBoxY1, EditBoxX2, EditBoxY2))
     {
      Print("Entry Price ボックスの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   entryPriceEdit.Text(DoubleToString(0, Digits()));
   entryPriceValue = 0.00;
   if(!UIPanel.Add(entryPriceEdit))
     {
      Print("Entry Price ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Entry Price +プラス ボタンの作成 ---
   if(!entryPricePlusButton.Create(0, "EntryPricePlus", 0, 170, 47, 189, 60))
     {
      Print("Entry Price + ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   entryPricePlusButton.Text("+");
   if(!UIPanel.Add(entryPricePlusButton))
     {
      Print("Entry Price + ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Entry Price -マイナス ボタンの作成 ---
   if(!entryPriceMinusButton.Create(0, "EntryPriceMinus", 0, 170, 60, 189, 73))
     {
      Print("Entry Price - ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   entryPriceMinusButton.Text("-");
   if(!UIPanel.Add(entryPriceMinusButton))
     {
      Print("Entry Price - ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Entry Price キーショートカット ラベルの作成 ---
   if(!EntryKeyLabel.Create(0, "EntryKeyLabel", 0, EditLabelX+72, EditLabelY+19, 0, 0))
     {
      Print("Entry Key ラベルの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   EntryKeyLabel.Text("-- E --");
   ObjectSetInteger(0, EntryKeyLabel.Name(), OBJPROP_FONTSIZE, 8);
   if(!UIPanel.Add(EntryKeyLabel))
     {
      Print("Entry Key ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- SL Price ラベルの作成 ---
   if(!slLabel.Create(0, "SlLabel", 0, EditLabelX, EditLabelY+EditLabelDistance, 0, 0))
     {
      Print("SL Price ラベルの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   slLabel.Text("SL Price:");
   if(!UIPanel.Add(slLabel))
     {
      Print("SL Price ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- SL Price 編集ボックスの作成 ---
   if(!slEdit.Create(0, "SlEdit", 0, EditBoxX1, EditBoxY1+(EditBoxDistance*1), EditBoxX2, EditBoxY2+(EditBoxDistance*1)))
     {
      Print("SL Price ボックスの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   slEdit.Text(DoubleToString(slValue, Digits()));
   if(!UIPanel.Add(slEdit))
     {
      Print("SL Price ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- SL Price + ボタンの作成 ---
   if(!slPlusButton.Create(0, "SlPlus", 0, 170, EditBoxY1+(EditBoxDistance*1)-1, 189, EditBoxY1+(EditBoxDistance*1)+12))
     {
      Print("SL Price + ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   slPlusButton.Text("+");
   if(!UIPanel.Add(slPlusButton))
     {
      Print("SL Price + ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- SL Price - ボタンの作成 ---
   if(!slMinusButton.Create(0, "SlMinus", 0, 170, EditBoxY1+(EditBoxDistance*1)+12, 189, EditBoxY1+(EditBoxDistance*1)+25))
     {
      Print("SL Price - ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   slMinusButton.Text("-");
   if(!UIPanel.Add(slMinusButton))
     {
      Print("SL Price - ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Stop Price キーショートカット ラベルの作成 ---
   if(!StopKeyLabel.Create(0, "StopKeyLabel", 0, EditLabelX+72, EditLabelY+EditLabelDistance+19, 0, 0))
     {
      Print("Stop Key ラベルの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   StopKeyLabel.Text("-- S --");
   ObjectSetInteger(0, StopKeyLabel.Name(), OBJPROP_FONTSIZE, 8);
   if(!UIPanel.Add(StopKeyLabel))
     {
      Print("Stop Key ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- TP Price ラベルの作成 ---
   if(!tpLabel.Create(0, "TpLabel", 0, EditLabelX, EditLabelY+(EditLabelDistance*2), 0, 0))
     {
      Print("TP Price ラベルの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   tpLabel.Text("TP Price:");
   if(!UIPanel.Add(tpLabel))
     {
      Print("TP Price ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- TP Price 編集ボックスの作成 ---
   if(!tpEdit.Create(0, "TpEdit", 0, EditBoxX1, EditBoxY1+(EditBoxDistance*2), EditBoxX2, EditBoxY2+(EditBoxDistance*2)))
     {
      Print("TP Price ボックスの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   tpEdit.Text(DoubleToString(tpValue, Digits()));
   if(!UIPanel.Add(tpEdit))
     {
      Print("TP Price ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- TP Price + ボタンの作成 ---
   if(!tpPlusButton.Create(0, "TpPlus", 0, 170, EditBoxY1+(EditBoxDistance*2)-1, 189, EditBoxY1+(EditBoxDistance*2)+12))
     {
      Print("TP Price + ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   tpPlusButton.Text("+");
   if(!UIPanel.Add(tpPlusButton))
     {
      Print("TP Price + ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- TP Price - ボタンの作成 ---
   if(!tpMinusButton.Create(0, "TpMinus", 0, 170, EditBoxY1+(EditBoxDistance*2)+12, 189, EditBoxY1+(EditBoxDistance*2)+25))
     {
      Print("TP Price - ボタンの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   tpMinusButton.Text("-");
   if(!UIPanel.Add(tpMinusButton))
     {
      Print("TP Price - ボタンのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Profit Price キーショートカット ラベルの作成 ---
   if(!ProfitKeyLabel.Create(0, "ProfitKeyLabel", 0, EditLabelX+72, EditLabelY+(EditLabelDistance*2)+19, 0, 0))
     {
      Print("Profit Key ラベルの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   ProfitKeyLabel.Text("-- P --");
   ObjectSetInteger(0, ProfitKeyLabel.Name(), OBJPROP_FONTSIZE, 8);
   if(!UIPanel.Add(ProfitKeyLabel))
     {
      Print("Profit Key ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- Risk Percent Label ラベル ----
   if(!riskPercentLabel.Create(0, "riskPercentLabel", 0, EditLabelX+9, EditLabelY+(EditLabelDistance*3), 0, 0))
     {
      Print("riskPercentLabel - 作成失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   riskPercentLabel.Text("Risk % :");
   if(!UIPanel.Add(riskPercentLabel))
     {
      Print("riskPercentLabel ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Risk Percent Edit 入力欄 ----
   if(!riskPercentEdit.Create(0, "riskPercentEdit", 0, EditBoxX1, EditBoxY1+(EditBoxDistance*3), EditBoxX2, EditBoxY2+(EditBoxDistance*3)))
     {
      Print("riskPercent入力欄 - 作成失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   riskPercentEdit.Text(DoubleToString(RiskPercent, 2));
   if(!UIPanel.Add(riskPercentEdit))
     {
      Print("risk% ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- Lot Label ラベル ---
   if(!CulLotLabel.Create(0, "CulLotLabel", 0, EditLabelX+21, EditLabelY+(EditLabelDistance*4), 0, 0))
     {
      Print("CulLotLabel - 作成失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   CulLotLabel.Text("Lot :");
   if(!UIPanel.Add(CulLotLabel))
     {
      Print("CulLotLabel ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- CulLot Edit ---
   if(!CulLotEdit.Create(0, "CulLotEdit", 0, EditBoxX1, EditBoxY1+(EditBoxDistance*4), EditBoxX2, EditBoxY2+(EditBoxDistance*4)))
     {
      Print("CulLotEdit - 作成失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   CulLotEdit.Text(DoubleToString(CulLotValue, 2));
   if(!UIPanel.Add(CulLotEdit))
     {
      Print("CulLotEdit ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- Risk $ Label　ラベル ---
   if(!RiskUSDLabel.Create(0, "RiskUSDLabel", 0, EditLabelX+14, EditLabelY+(EditLabelDistance*5), 0, 0))
     {
      Print("RiskUSDLabel - 作成失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   RiskUSDLabel.Text("Risk $ :");
   if(!UIPanel.Add(RiskUSDLabel))
     {
      Print("RiskUSDLabel ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Risk $ Edit ---
   if(!RiskUSDEdit.Create(0, "RiskUSDEdit", 0, EditBoxX1, EditBoxY1+(EditBoxDistance*5), EditBoxX2, EditBoxY2+(EditBoxDistance*5)))
     {
      Print("RiskUSDEdit - 作成失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   RiskUSDEdit.Text(DoubleToString(RiskUSDValue, 2));
   ObjectSetInteger(0, RiskUSDEdit.Name(), OBJPROP_READONLY, true);
   ObjectSetInteger(0, RiskUSDEdit.Name(), OBJPROP_BGCOLOR, clrLightGray);
   if(!UIPanel.Add(RiskUSDEdit))
     {
      Print("RiskUSDEdit ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- ConfirmCheckBox　Label ---
   if(!ConfirmCheckBoxLabel.Create(0, "OrderConfirmCheckBoxLabel", 0, EditLabelX+5, EditLabelY+(EditLabelDistance*5)+28, 0, 0))
     {
      Print("ConfirmCheckBoxLabel - 作成失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   ConfirmCheckBoxLabel.Text("noConfirm:");
   ObjectSetInteger(0, ConfirmCheckBoxLabel.Name(), OBJPROP_FONTSIZE, 9);
   if(!UIPanel.Add(ConfirmCheckBoxLabel))
     {
      Print("ConfirmCheckBoxLabel ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- ConfirmCheckBox ---
   if(!ConfirmCheckBox.Create(0, "ConfirmCheckBox", 0, EditBoxX1-3, EditBoxY1+(EditBoxDistance*5)+28, EditBoxX1+17, EditBoxY2+(EditBoxDistance*5)+28))
     {
      Print("ConfirmCheckBox - 作成失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   ConfirmCheckBox.Text("");
   ConfirmCheckBox.Checked(false); // MQL4のCCheckBoxにCheckedがある場合 -> 初期値はfalse
// ConfirmCheckBox.Checked(false); // MQL4のCCheckBoxにCheckedがある場合 -> 初期値はfalse
   if(!UIPanel.Add(ConfirmCheckBox))
     {
      Print("ConfirmCheckBox ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- ライン表示/非表示 切り替えボタンの作成 ---
   if(!linesToggleButton.Create(0, "LinesToggleButton", 0, EditBoxX1+22, EditBoxY1+(EditBoxDistance*5)+26, EditBoxX2, EditBoxY2+(EditBoxDistance*5)+26+2))
     {
      Print("Lines Toggle Button 作成失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   linesToggleButton.Text(g_showLines ? "Lines: ON" : "Lines: OFF");
   ObjectSetInteger(0, linesToggleButton.Name(), OBJPROP_FONTSIZE, 9);
   if(!UIPanel.Add(linesToggleButton))
     {
      Print("Lines Toggle Button パネルへの追加失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

//--- Order Button ----
   if(!OrderButton.Create(0, "OrderButton", 0, EditBoxX1, EditBoxY1+(EditBoxDistance*6)+21, EditBoxX2, EditBoxY2+(EditBoxDistance*6)+25))
     {
      Print("OrderButton - 作成失敗");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   OrderButton.Text("Order");
   if(!UIPanel.Add(OrderButton))
     {
      Print("OrderButton ボックスのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
//--- Order Key Label キーショートカット ラベルの作成 ---
   if(!OrderKeyLabel.Create(0, "OrderKeyLabel", 0, EditLabelX+72, EditLabelY+(EditLabelDistance*6)+44, 0, 0))
     {
      Print("Order Key ラベルの作成に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }
   OrderKeyLabel.Text("-- Shift + T --");
   ObjectSetInteger(0, OrderKeyLabel.Name(), OBJPROP_FONTSIZE, 8);
   if(!UIPanel.Add(OrderKeyLabel))
     {
      Print("Order Key ラベルのパネルへの追加に失敗しました。");
      UIPanel.Destroy();
      appDialog.Destroy();
      return(INIT_FAILED);
     }

// --- JLC.mq5 から移植 --
   EventSetTimer(1); // 1秒ごとにOnTimer()を呼び出す

   UpdateEntryPriceEditBoxState(); // 初期状態を反映
   UpdateAllLines();               // ラインの初期表示
   CalculateLotSizeAndRisk();      // ロットサイズの初期計算

// チャートのプロパティを設定してダイアログを最前面に維持
   ChartSetInteger(0, CHART_BRING_TO_TOP, false);  // チャートが最前面に来ないように設定

   ChartRedraw(); // 強制的に再描画
   UIPanel.Visible(true);
//appDialog.Show();
   appDialog.Run(); // appDialog を起動

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer(); // タイマーを停止

// ラインオブジェクトを削除
   DeleteAllLines();
   DeleteEtSlTpInfoLabels();

   appDialog.Destroy(reason); // appDialog が管理下のコントロールも破棄する
// UIPanel.Destroy();   // UIPanel は appDialog によって破棄される

   ChartRedraw();
   Print("OnDeinit reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// EAのメインロジックをここに実装
// OnTimerで処理するため、OnTickでは通常何もしないか、高頻度な処理を記述
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
// 成り行き注文モードの場合のみ、価格表示を更新
   if(isMarketOrder)
     {
      UpdateEntryPriceEditBoxState();
     }

   CalculateLotSizeAndRisk();

// ラインが表示されている場合のみラベルを更新
   if(g_showLines)
     {
      UpdateEtSlTpInfoLabels();
     }
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
// マウス移動イベント: 座標をグローバル変数に保存
   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      g_mouse_last_x = lparam;
      g_mouse_last_y = (long)dparam;
      // MQL4ではChartXYToTimePriceの第4引数でサブウィンドウIDを直接取得できないため、
      // クリック時などにサブウィンドウを判定する必要がある。
      // ここでは単純に座標のみ保存。
      // CHARTEVENT_MOUSE_MOVE も appDialog.ChartEvent に渡すため、ここでの return は削除
     }

// ダイアログイベントを処理
   appDialog.ChartEvent(id, lparam, dparam, sparam);

   UIPanel.OnEvent(id, lparam, dparam, sparam);

// --- Buy/Sell ボタンクリック ---
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == buySellButton.Name())
     {
      isBuyMode = !isBuyMode;
      buySellButton.Text(isBuyMode ? "Buy" : "Sell");
      UpdateEntryPriceEditBoxState();
      CalculateLotSizeAndRisk();
      UpdateAllLines();
      ChartRedraw();
      return;
     }

// --- Market/Limit ボタンクリック ---
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == marketLimitButton.Name())
     {
      isMarketOrder = !isMarketOrder;
      marketLimitButton.Text(isMarketOrder ? "Market" : "Limit");
      UpdateEntryPriceEditBoxState();
      UpdateAllLines();
      CalculateLotSizeAndRisk();
      ChartRedraw();
      return;
     }

// --- Entry Price Edit Box 編集完了 ---
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == entryPriceEdit.Name())
     {
      string inputText = entryPriceEdit.Text();
      double price = StringToDouble(inputText);
      double normalizedPrice = NormalizeDouble(price, Digits());
      entryPriceEdit.Text(DoubleToString(normalizedPrice, Digits()));
      if(price > 0)
        {
         entryPriceValue = normalizedPrice;
        }
      else
        {
         entryPriceEdit.Text(DoubleToString(entryPriceValue, Digits())); // 無効なら元に戻す
        }
      UpdateAllLines();
      CalculateLotSizeAndRisk();
      return;
     }

// --- Entry Price +/- ボタン ---
   if(id == CHARTEVENT_OBJECT_CLICK && (sparam == entryPricePlusButton.Name() || sparam == entryPriceMinusButton.Name()))
     {
      if(!isMarketOrder) // 指値モードのみ
        {
         double point = MarketInfo(Symbol(), MODE_POINT);
         if(sparam == entryPricePlusButton.Name())
            entryPriceValue = NormalizeDouble(entryPriceValue + point, Digits());
         else
            entryPriceValue = NormalizeDouble(entryPriceValue - point, Digits());
         if(entryPriceValue < 0)
            entryPriceValue = 0; // 0未満にはしない
         entryPriceEdit.Text(DoubleToString(entryPriceValue, Digits()));
         UpdateAllLines();
         CalculateLotSizeAndRisk();
        }
      return;
     }

// --- SL Price Edit Box 編集完了 ---
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == slEdit.Name())
     {
      string inputText = slEdit.Text();
      double price = StringToDouble(inputText);
      double normalizedPrice = NormalizeDouble(price, Digits());
      slEdit.Text(DoubleToString(normalizedPrice, Digits()));
      if(price > 0)
        {
         slValue = normalizedPrice;
        }
      else
        {
         slEdit.Text(DoubleToString(slValue, Digits()));
        }
      UpdateAllLines();
      CalculateLotSizeAndRisk();
      return;
     }

// --- SL Price +/- ボタン ---
   if(id == CHARTEVENT_OBJECT_CLICK && (sparam == slPlusButton.Name() || sparam == slMinusButton.Name()))
     {
      double point = MarketInfo(Symbol(), MODE_POINT);
      if(sparam == slPlusButton.Name())
         slValue = NormalizeDouble(slValue + point, Digits());
      else
         slValue = NormalizeDouble(slValue - point, Digits());
      if(slValue < 0)
         slValue = 0;
      slEdit.Text(DoubleToString(slValue, Digits()));
      UpdateAllLines();
      CalculateLotSizeAndRisk();
      return;
     }

// --- TP Price Edit Box 編集完了 ---
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == tpEdit.Name())
     {
      string inputText = tpEdit.Text();
      double price = StringToDouble(inputText);
      double normalizedPrice = NormalizeDouble(price, Digits());
      tpEdit.Text(DoubleToString(normalizedPrice, Digits()));
      if(price >= 0) // TPは0でもOK (TPなし)
        {
         tpValue = normalizedPrice;
        }
      else
        {
         tpEdit.Text(DoubleToString(tpValue, Digits()));
        }
      UpdateAllLines();
      return;
     }

// --- TP Price +/- ボタン ---
   if(id == CHARTEVENT_OBJECT_CLICK && (sparam == tpPlusButton.Name() || sparam == tpMinusButton.Name()))
     {
      double point = MarketInfo(Symbol(), MODE_POINT);
      if(sparam == tpPlusButton.Name())
         tpValue = NormalizeDouble(tpValue + point, Digits());
      else
         tpValue = NormalizeDouble(tpValue - point, Digits());
      if(tpValue < 0)
         tpValue = 0;
      tpEdit.Text(DoubleToString(tpValue, Digits()));
      UpdateAllLines();
      return;
     }

// --- Risk Percent Edit Box 編集完了 ---
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == riskPercentEdit.Name())
     {
      string inputText = riskPercentEdit.Text();
      double percent = StringToDouble(inputText);
      if(percent > 0 && percent <= 100.0)
        {
         RiskPercent = percent;
         riskPercentEdit.Text(DoubleToString(RiskPercent, 2));
        }
      else
        {
         riskPercentEdit.Text(DoubleToString(RiskPercent, 2)); // 無効なら元に戻す
        }
      CalculateLotSizeAndRisk();
      return;
     }

// --- Lines Toggle Button クリック ---
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == linesToggleButton.Name())
     {
      g_showLines = !g_showLines;
      linesToggleButton.Text(g_showLines ? "Lines: ON" : "Lines: OFF");
      UpdateAllLines();
      ChartRedraw();
      return;
     }

// --- Order Button クリック ---
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == OrderButton.Name())
     {
      bool skipConfirm = ConfirmCheckBox.Checked();
      if(!skipConfirm)
        {
         string confirmMsg = StringFormat("Order Confirm:\nSymbol: %s\nType: %s %s\nLot: %.2f\nEntry: %s\nSL: %s\nTP: %s",
                                          Symbol(),
                                          (isMarketOrder ? "Market" : "Limit"),
                                          (isBuyMode ? "Buy" : "Sell"),
                                          CulLotValue,
                                          (isMarketOrder ? "Current" : DoubleToString(entryPriceValue, Digits())),
                                          (slValue > 0 ? DoubleToString(slValue, Digits()) : "None"),
                                          (tpValue > 0 ? DoubleToString(tpValue, Digits()) : "None"));
         int result = MessageBox(confirmMsg, "Confirm Order", MB_YESNO | MB_ICONQUESTION);
         if(result != IDYES)
           {
            Print("Order cancelled by user.");
            return;
           }
        }
      SendOrder();
      return;
     }

// --- キーボードイベント ---
   if(id == CHARTEVENT_KEYDOWN) // MQL4のキーダウンイベントIDに修正
     {
      // Shift + T で注文
      bool isTKeyPressed = (lparam == 84); // 'T'
      // MQL4のdparam: 1=Shift, 2=Ctrl, 4=Alt (ビットマスクではない)
      // JLC.mq5では (dparam & 1) != 0 でShiftを判定していたが、MQL4では dparam == 1 (Shiftのみ) または他の組み合わせ
      bool isShiftPressed = ((int)dparam & 1) != 0; // JLC.mq5のShift判定に合わせる (ビット0)

      if(isTKeyPressed && isShiftPressed)
        {
         // OrderButtonクリックと同じ処理
         bool skipConfirm = ConfirmCheckBox.Checked();
         if(!skipConfirm)
           {
            string confirmMsg = StringFormat("Order Confirm (Key):\nSymbol: %s\nType: %s %s\nLot: %.2f\nEntry: %s\nSL: %s\nTP: %s",
                                             Symbol(),
                                             (isMarketOrder ? "Market" : "Limit"),
                                             (isBuyMode ? "Buy" : "Sell"),
                                             CulLotValue,
                                             (isMarketOrder ? "Current" : DoubleToString(entryPriceValue, Digits())),
                                             (slValue > 0 ? DoubleToString(slValue, Digits()) : "None"),
                                             (tpValue > 0 ? DoubleToString(tpValue, Digits()) : "None"));
            int result = MessageBox(confirmMsg, "Confirm Order", MB_YESNO | MB_ICONQUESTION);
            if(result != IDYES)
              {
               Print("Order cancelled by user (Key).");
               return;
              }
           }
         SendOrder();
         return;
        }

      // E, S, P キーで価格設定
      double price_at_cursor = 0;
      datetime time_at_cursor;
      int window = 0;
      // ChartXYToTimePriceの第4引数はMQL4ではウィンドウハンドルではなくサブウィンドウインデックス
      // マウスカーソルがチャート上にあるかどうかの簡易的なチェック
      if(g_mouse_last_x >= 0 && g_mouse_last_y >= 0)
        {
         if(ChartXYToTimePrice(0, (int)g_mouse_last_x, (int)g_mouse_last_y, window, time_at_cursor, price_at_cursor))
           {
            price_at_cursor = NormalizeDouble(price_at_cursor, Digits());

            if(lparam == 69) // 'E' - Entry Price
              {
               if(!isMarketOrder)
                 {
                  entryPriceValue = price_at_cursor;
                  entryPriceEdit.Text(DoubleToString(entryPriceValue, Digits()));
                  UpdateAllLines();
                  CalculateLotSizeAndRisk();
                  Print("Entry Price set by key 'E': ", entryPriceValue);
                 }
              }
            else
               if(lparam == 83) // 'S' - SL Price
                 {
                  slValue = price_at_cursor;
                  slEdit.Text(DoubleToString(slValue, Digits()));
                  UpdateAllLines();
                  CalculateLotSizeAndRisk();
                  Print("SL Price set by key 'S': ", slValue);
                 }
               else
                  if(lparam == 80) // 'P' - TP Price
                    {
                     tpValue = price_at_cursor;
                     tpEdit.Text(DoubleToString(tpValue, Digits()));
                     UpdateAllLines();
                     // TP変更ではロット計算は不要なことが多い
                     Print("TP Price set by key 'P': ", tpValue);
                    }
           }
         else
           {
            if(lparam == 69 || lparam == 83 || lparam == 80)
               Print("Failed to get price at cursor or cursor is not on the main chart window.");
           }
        }
      else
        {
         if(lparam == 69 || lparam == 83 || lparam == 80)
            Print("Mouse cursor position not recorded yet or invalid.");
        }
      // キーイベントはここで処理完了とみなし、以降の appDialog.ChartEvent に渡さないようにする
      // ただし、他のコントロールがキーイベントを必要とする場合はこの return を見直す
      if(lparam == 84 || lparam == 69 || lparam == 83 || lparam == 80)
         return;
     }

// --- ラインドラッグイベント ---
   if(id == CHARTEVENT_OBJECT_DRAG)
     {
      // ラインをドラッグしたときに価格を更新
      double price_drag=0;
      datetime time_drag=0;

      if(sparam == entryPriceLineName)
        {
         price_drag = ObjectGetDouble(0, sparam, OBJPROP_PRICE1);
         entryPriceValue = NormalizeDouble(price_drag, Digits());
         entryPriceEdit.Text(DoubleToString(entryPriceValue, Digits()));
        }
      else
         if(sparam == slLineName)
           {
            price_drag = ObjectGetDouble(0, sparam, OBJPROP_PRICE1);
            slValue = NormalizeDouble(price_drag, Digits());
            slEdit.Text(DoubleToString(slValue, Digits()));
           }
         else
            if(sparam == tpLineName)
              {
               price_drag = ObjectGetDouble(0, sparam, OBJPROP_PRICE1);
               tpValue = NormalizeDouble(price_drag, Digits());
               tpEdit.Text(DoubleToString(tpValue, Digits()));
              }
      CalculateLotSizeAndRisk();
      UpdateEtSlTpInfoLabels();
      ChartRedraw();
      // }
     }
  }
//+------------------------------------------------------------------+
//| エントリー価格欄の状態を更新する関数                             |
//+------------------------------------------------------------------+
void UpdateEntryPriceEditBoxState()
  {
   if(isMarketOrder)
     {
      // entryPriceEdit.ReadOnly(true); // CEditにReadOnlyメソッドがない場合がある
      ObjectSetInteger(0, entryPriceEdit.Name(), OBJPROP_READONLY, true);
      ObjectSetInteger(0, entryPriceEdit.Name(), OBJPROP_BGCOLOR, clrLightGray);
      ObjectSetInteger(0, entryPricePlusButton.Name(), OBJPROP_STATE, false);
      ObjectSetInteger(0, entryPriceMinusButton.Name(), OBJPROP_STATE, false);

      double priceToSet = 0.0;
      if(isBuyMode)
         priceToSet = MarketInfo(Symbol(), MODE_ASK);
      else
         priceToSet = MarketInfo(Symbol(), MODE_BID);

      if(priceToSet > 0)
        {
         entryPriceValue = NormalizeDouble(priceToSet, Digits());
         entryPriceEdit.Text(DoubleToString(entryPriceValue, Digits()));
        }
     }
   else // Limit Order
     {
      // entryPriceEdit.ReadOnly(false);
      ObjectSetInteger(0, entryPriceEdit.Name(), OBJPROP_READONLY, false);
      ObjectSetInteger(0, entryPriceEdit.Name(), OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, entryPricePlusButton.Name(), OBJPROP_STATE, true);
      ObjectSetInteger(0, entryPriceMinusButton.Name(), OBJPROP_STATE, true);

      if(entryPriceValue == 0.0) // 指値モードでentryPriceValueが0の場合、現在の価格から少し離れた値を初期値とする
        {
         double refPrice = isBuyMode ? MarketInfo(Symbol(), MODE_ASK) : MarketInfo(Symbol(), MODE_BID);
         // デフォルトで少し有利な方向に指値を置く (例: Buy Limitなら現在価格より下)
         entryPriceValue = NormalizeDouble(refPrice + (isBuyMode ? -1 : 1) * MarketInfo(Symbol(), MODE_POINT) * 10, Digits());
         if(entryPriceValue <=0)
            entryPriceValue = NormalizeDouble(MarketInfo(Symbol(),MODE_POINT), Digits()); // 0以下になったら最小ポイントに
        }
      entryPriceEdit.Text(DoubleToString(entryPriceValue, Digits()));
     }
// RiskUSDEdit は常に読み取り専用で背景グレー
   ObjectSetInteger(0, RiskUSDEdit.Name(), OBJPROP_READONLY, true);
   ObjectSetInteger(0, RiskUSDEdit.Name(), OBJPROP_BGCOLOR, clrLightGray);
// CulLotEdit もロット計算結果表示用なので読み取り専用にする場合
   ObjectSetInteger(0, CulLotEdit.Name(), OBJPROP_READONLY, true);
   ObjectSetInteger(0, CulLotEdit.Name(), OBJPROP_BGCOLOR, clrLightGray);


   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| 全てのラインの価格を更新/表示/非表示する関数                     |
//+------------------------------------------------------------------+
void UpdateAllLines()
  {
   if(!g_showLines)
     {
      DeleteAllLines();
      DeleteEtSlTpInfoLabels();
      ChartRedraw();
      return;
     }

   double currentEntryForLine = 0; // ライン表示用のエントリー価格
   if(isMarketOrder)
     {
      // 成行の場合、ラインは表示しないか、現在のAsk/Bidに表示するか選択できる。
      // JLC.mq5では成行の場合エントリーラインは表示しないので、それに合わせる。
      if(ObjectFind(0, entryPriceLineName) != -1)
         ObjectDelete(0, entryPriceLineName);
     }
   else
     {
      currentEntryForLine = entryPriceValue;
      if(currentEntryForLine > 0)
        {
         if(ObjectFind(0, entryPriceLineName) == -1)
           {
            ObjectCreate(0, entryPriceLineName, OBJ_HLINE, 0, 0, currentEntryForLine);
            ObjectSetInteger(0, entryPriceLineName, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, entryPriceLineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, entryPriceLineName, OBJPROP_WIDTH, 1);
            ObjectSetString(0, entryPriceLineName, OBJPROP_TOOLTIP, "Entry Price");
            ObjectSetInteger(0, entryPriceLineName, OBJPROP_SELECTABLE, true); // MQL4ではドラッグは別途実装が必要
            ObjectSetInteger(0, entryPriceLineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, entryPriceLineName, OBJPROP_SELECTED, true);
           }
         else
           {
            ObjectSetDouble(0, entryPriceLineName, OBJPROP_PRICE1, currentEntryForLine);
           }
        }
      else
        {
         if(ObjectFind(0, entryPriceLineName) != -1)
            ObjectDelete(0, entryPriceLineName);
        }
     }


// SL Price Line
   if(slValue > 0)
     {
      if(ObjectFind(0, slLineName) == -1)
        {
         ObjectCreate(0, slLineName, OBJ_HLINE, 0, 0, slValue);
         ObjectSetInteger(0, slLineName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, slLineName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, slLineName, OBJPROP_WIDTH, 1);
         ObjectSetString(0, slLineName, OBJPROP_TOOLTIP, "Stop Loss");
         ObjectSetInteger(0, slLineName, OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, slLineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, slLineName, OBJPROP_SELECTED, true);
        }
      else
        {
         ObjectSetDouble(0, slLineName, OBJPROP_PRICE1, slValue);
        }
     }
   else
     {
      if(ObjectFind(0, slLineName) != -1)
         ObjectDelete(0, slLineName);
     }

// TP Price Line
   if(tpValue > 0)
     {
      if(ObjectFind(0, tpLineName) == -1)
        {
         ObjectCreate(0, tpLineName, OBJ_HLINE, 0, 0, tpValue);
         ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, clrAqua);
         ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, tpLineName, OBJPROP_WIDTH, 1);
         ObjectSetString(0, tpLineName, OBJPROP_TOOLTIP, "Take Profit");
         ObjectSetInteger(0, tpLineName, OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, tpLineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, tpLineName, OBJPROP_SELECTED, true);
        }
      else
        {
         ObjectSetDouble(0, tpLineName, OBJPROP_PRICE1, tpValue);
        }
     }
   else
     {
      if(ObjectFind(0, tpLineName) != -1)
         ObjectDelete(0, tpLineName);
     }

   UpdateEtSlTpInfoLabels();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| 全てのラインを削除する関数                                       |
//+------------------------------------------------------------------+
void DeleteAllLines()
  {
   if(ObjectFind(0, entryPriceLineName) != -1)
      ObjectDelete(0, entryPriceLineName);
   if(ObjectFind(0, slLineName) != -1)
      ObjectDelete(0, slLineName);
   if(ObjectFind(0, tpLineName) != -1)
      ObjectDelete(0, tpLineName);
  }

//+------------------------------------------------------------------+
//| ET/SL/TP情報ラベルを作成/更新/削除する関数                       |
//+------------------------------------------------------------------+
void UpdateEtSlTpInfoLabels()
  {
   if(!g_showLines)
     {
      DeleteEtSlTpInfoLabels();
      return;
     }

   double point = MarketInfo(Symbol(), MODE_POINT);
   double referencePrice = 0.0; // 計算基準となる価格

   if(isMarketOrder)
     {
      // 成行の場合、現在のAsk/Bidを基準にする
      referencePrice = isBuyMode ? MarketInfo(Symbol(), MODE_ASK) : MarketInfo(Symbol(), MODE_BID);
     }
   else
     {
      // 指値の場合、設定されたエントリー価格を基準にする
      referencePrice = entryPriceValue;
     }
   if(referencePrice <= 0 && !isMarketOrder)    // 指値でエントリー価格がまだ有効でない場合はラベル消去
     {
      DeleteEtSlTpInfoLabels();
      return;
     }

//--- ET情報ラベル
   if(!isMarketOrder && entryPriceValue>0 && ObjectFind(0,entryPriceLineName)!=-1)
     {
      int x_px,y_px;
      datetime now=Time[0];
      if(ChartTimePriceToXY(0,0,now,entryPriceValue,x_px,y_px))
        {
         if(ObjectFind(0,etInfoLabelName)==-1)
           {
            ObjectCreate(0,etInfoLabelName,OBJ_LABEL,0,0,0);
            ObjectSetInteger(0,etInfoLabelName,OBJPROP_COLOR,clrGreen);
            ObjectSetInteger(0,etInfoLabelName,OBJPROP_FONTSIZE,9);
            ObjectSetInteger(0,etInfoLabelName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,etInfoLabelName,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
            ObjectSetInteger(0,etInfoLabelName,OBJPROP_ANCHOR,ANCHOR_RIGHT);
           }
         ObjectSetString(0,etInfoLabelName,OBJPROP_TEXT,"ET:");
         ObjectSetInteger(0,etInfoLabelName,OBJPROP_XDISTANCE,5);
         ObjectSetInteger(0,etInfoLabelName,OBJPROP_YDISTANCE,y_px-9);
        }
      else
         if(ObjectFind(0,etInfoLabelName)!=-1)
            ObjectDelete(0,etInfoLabelName);
     }
   else
      if(ObjectFind(0,etInfoLabelName)!=-1)
         ObjectDelete(0,etInfoLabelName);

//--- SL情報ラベル
   if(slValue>0 && referencePrice>0 && ObjectFind(0,slLineName)!=-1)
     {
      double pips_val=(isBuyMode?(referencePrice-slValue):(slValue-referencePrice))/point;
      string slText=StringFormat("SL: %.0f",pips_val);
      int x_px,y_px;
      datetime now=Time[0];
      if(ChartTimePriceToXY(0,0,now,slValue,x_px,y_px))
        {
         if(ObjectFind(0,slInfoLabelName)==-1)
           {
            ObjectCreate(0,slInfoLabelName,OBJ_LABEL,0,0,0);
            ObjectSetInteger(0,slInfoLabelName,OBJPROP_COLOR,clrRed);
            ObjectSetInteger(0,slInfoLabelName,OBJPROP_FONTSIZE,9);
            ObjectSetInteger(0,slInfoLabelName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,slInfoLabelName,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
            ObjectSetInteger(0,slInfoLabelName,OBJPROP_ANCHOR,ANCHOR_RIGHT);
           }
         ObjectSetString(0,slInfoLabelName,OBJPROP_TEXT,slText);
         ObjectSetInteger(0,slInfoLabelName,OBJPROP_XDISTANCE,5);
         ObjectSetInteger(0,slInfoLabelName,OBJPROP_YDISTANCE,y_px-9);
        }
      else
         if(ObjectFind(0,slInfoLabelName)!=-1)
            ObjectDelete(0,slInfoLabelName);
     }
   else
      if(ObjectFind(0,slInfoLabelName)!=-1)
         ObjectDelete(0,slInfoLabelName);

//--- TP情報ラベル
   if(tpValue>0 && referencePrice>0 && ObjectFind(0,tpLineName)!=-1)
     {
      double pips_val=(isBuyMode?(tpValue-referencePrice):(referencePrice-tpValue))/point;
      string tpText=StringFormat("TP: %.0f",pips_val);
      int x_px,y_px;
      datetime now=Time[0];
      if(ChartTimePriceToXY(0,0,now,tpValue,x_px,y_px))
        {
         if(ObjectFind(0,tpInfoLabelName)==-1)
           {
            ObjectCreate(0,tpInfoLabelName,OBJ_LABEL,0,0,0);
            ObjectSetInteger(0,tpInfoLabelName,OBJPROP_COLOR,clrAqua);
            ObjectSetInteger(0,tpInfoLabelName,OBJPROP_FONTSIZE,9);
            ObjectSetInteger(0,tpInfoLabelName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,tpInfoLabelName,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
            ObjectSetInteger(0,tpInfoLabelName,OBJPROP_ANCHOR,ANCHOR_RIGHT);
           }
         ObjectSetString(0,tpInfoLabelName,OBJPROP_TEXT,tpText);
         ObjectSetInteger(0,tpInfoLabelName,OBJPROP_XDISTANCE,5);
         ObjectSetInteger(0,tpInfoLabelName,OBJPROP_YDISTANCE,y_px-9);
        }
      else
         if(ObjectFind(0,tpInfoLabelName)!=-1)
            ObjectDelete(0,tpInfoLabelName);
     }
   else
      if(ObjectFind(0,tpInfoLabelName)!=-1)
         ObjectDelete(0,tpInfoLabelName);
   ChartRedraw(); // ラベル更新後に再描画
  }
//+------------------------------------------------------------------+
//| SL/TP情報ラベルを削除する関数                                    |
//+------------------------------------------------------------------+
void DeleteEtSlTpInfoLabels()
  {
   if(ObjectFind(0, etInfoLabelName) != -1)
      ObjectDelete(0, etInfoLabelName);
   if(ObjectFind(0, slInfoLabelName) != -1)
      ObjectDelete(0, slInfoLabelName);
   if(ObjectFind(0, tpInfoLabelName) != -1)
      ObjectDelete(0, tpInfoLabelName);
  }

//+------------------------------------------------------------------+
//| ロット数を正規化する関数                                         |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot)
  {
   double volume_min = MarketInfo(Symbol(), MODE_MINLOT);
   double volume_max = MarketInfo(Symbol(), MODE_MAXLOT);
   double volume_step = MarketInfo(Symbol(), MODE_LOTSTEP);

// volume_stepが0または非常に小さい値の場合のフォールバック
   if(volume_step <= 0.00000001)
      volume_step = 0.01;


   lot = MathRound(lot / volume_step) * volume_step;

   if(lot < volume_min && volume_min > 0)
      lot = volume_min; // volume_minが0より大きい場合のみ適用
   if(lot > volume_max && volume_max > 0)
      lot = volume_max; // volume_maxが0より大きい場合のみ適用

   return NormalizeDouble(lot, 2); // 通常ロットは小数点以下2桁
  }

//+------------------------------------------------------------------+
//| ロットサイズとリスク額を計算し、UIを更新する関数                   |
//+------------------------------------------------------------------+
void CalculateLotSizeAndRisk()
  {
   double accountBalance = AccountBalance();
   double entry = 0;
   double stopLoss = slValue;
   double riskPercent_val = RiskPercent;

   if(isMarketOrder)
     {
      entry = isBuyMode ? MarketInfo(Symbol(), MODE_ASK) : MarketInfo(Symbol(), MODE_BID);
     }
   else
     {
      entry = entryPriceValue;
     }

   if(accountBalance <= 0 || riskPercent_val <= 0 || stopLoss <= 0 || entry <= 0 || stopLoss == entry)
     {
      CulLotEdit.Text("0.00");
      RiskUSDEdit.Text("0.00");
      CulLotValue = 0.0;
      RiskUSDValue = 0.0;
      return;
     }

   double stopLossDiffPoints = MathAbs(entry - stopLoss) / MarketInfo(Symbol(), MODE_POINT);
   if(stopLossDiffPoints < MarketInfo(Symbol(), MODE_STOPLEVEL))
     {
      CulLotEdit.Text("0.00");
      RiskUSDEdit.Text("TooClose"); // SLが近すぎることを示す
      CulLotValue = 0.0;
      RiskUSDValue = 0.0;
      return;
     }

   double riskAmount = accountBalance * (riskPercent_val / 100.0);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE); // MODE_POINT と同じことが多いが、厳密にはTICKSIZE

   if(tickSize <= 0 || tickValue <=0) // tickSizeやtickValueが0または負の場合は計算不能
     {
      PrintFormat("Invalid TickSize (%.5f) or TickValue (%.2f) for %s", tickSize, tickValue, Symbol());
      CulLotEdit.Text("0.00");
      RiskUSDEdit.Text("Err");
      CulLotValue = 0.0;
      RiskUSDValue = 0.0;
      return;
     }

// 1ポイントあたりの価値 (口座通貨建て)
// MODE_TICKVALUEは1ティックの価値、MODE_TICKSIZEは1ティックの価格変動幅
// 1ポイントの価値 = (MODE_TICKVALUE / MODE_TICKSIZE) * MODE_POINT
// ただし、多くのブローカーで MODE_TICKVALUE は既に1ポイントあたりの価値（ロットサイズ1の場合）を示していることがある。
// または、MODE_TICKVALUE が 1 ロットを MODE_LOTSIZE の契約サイズで取引した際の、1 pip (または 1 point) の価値を示す。
// ここでは、stopLossDiff (価格差) を使って損失額を計算する。
// 1ロットあたりの損失額 = (価格差 / ティックサイズ) * ティックバリュー
// または、価格差(pips) * 1pipの価値
// MQL4のMarketInfo(Symbol(), MODE_TICKVALUE)は、1標準ロットのポジションが1ティック変動した場合の口座通貨での損益額。
// MQL4のMarketInfo(Symbol(), MODE_TICKSIZE)は、価格の最小変動幅（ティックサイズ）。
// 損切り幅（価格単位）/ ティックサイズ = 損切り幅（ティック単位）
// 損切り幅（ティック単位）* ティックバリュー = 1ロットあたりの損失額
   double lossPerLot = (MathAbs(entry - stopLoss) / tickSize) * tickValue;


   if(lossPerLot <= 0)
     {
      PrintFormat("Calculated lossPerLot is not positive: %.2f (Entry:%.5f, SL:%.5f, TickSize:%.5f, TickValue:%.2f)",
                  lossPerLot, entry, stopLoss, tickSize, tickValue);
      CulLotEdit.Text("0.00");
      RiskUSDEdit.Text("Err");
      CulLotValue = 0.0;
      RiskUSDValue = 0.0;
      return;
     }

   double calculatedLot = riskAmount / lossPerLot;
   CulLotValue = NormalizeLotSize(calculatedLot);

// 実際に発注するロットでのリスク額を再計算
   RiskUSDValue = lossPerLot * CulLotValue;

   CulLotEdit.Text(DoubleToString(CulLotValue, 2));
   RiskUSDEdit.Text(DoubleToString(RiskUSDValue, 2));
  }

//+------------------------------------------------------------------+
//| 注文を発行する関数                                               |
//+------------------------------------------------------------------+
void SendOrder()
  {
   if(CulLotValue < MarketInfo(Symbol(), MODE_MINLOT) && CulLotValue > 0) // 0より大きく、最小ロット未満の場合
     {
      Print("Lot size is less than minimum. Lot: ", CulLotValue, " MinLot: ", MarketInfo(Symbol(), MODE_MINLOT));
      MessageBox("Lot size (" + DoubleToString(CulLotValue,2) + ") is less than minimum (" + DoubleToString(MarketInfo(Symbol(), MODE_MINLOT),2) + ").", "Order Error", MB_OK | MB_ICONERROR);
      return;
     }
   if(CulLotValue == 0 && MarketInfo(Symbol(), MODE_MINLOT) > 0) // 最小ロットが0より大きいのにロットが0の場合
     {
      Print("Invalid Lot size: ", CulLotValue);
      MessageBox("Cannot place order: Lot size is zero.", "Order Error", MB_OK | MB_ICONERROR);
      return;
     }
// 最小ロットが0の場合 (ありえないが念のため) は CulLotValue == 0 のみで判定


   double lot_val = CulLotValue;
   double price_val = 0; // OrderSendのprice引数
   double sl_val = slValue;
   double tp_val = tpValue;
   int orderType_val;
   string comment_val = "LotCul_MT4";
   color arrow_color = CLR_NONE;

// SL/TPが0なら0.0にする (OrderSendのため)
   if(sl_val <= 0)
      sl_val = 0.0;
   if(tp_val <= 0)
      tp_val = 0.0;

// ストップレベル (ポイント単位)
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
   double point = MarketInfo(Symbol(), MODE_POINT);

   if(isMarketOrder)
     {
      orderType_val = isBuyMode ? OP_BUY : OP_SELL;
      price_val = isBuyMode ? MarketInfo(Symbol(), MODE_ASK) : MarketInfo(Symbol(), MODE_BID); // 成行の場合は現在価格
      arrow_color = isBuyMode ? clrBlue : clrRed;

      // SL/TPのストップレベルチェック (成行)
      if(sl_val != 0.0)
        {
         if(isBuyMode && (price_val - sl_val) < stopLevel * point)
           {
            MessageBox("SL is too close for Buy Market. Entry: "+DoubleToString(price_val,Digits())+", SL: "+DoubleToString(sl_val,Digits())+". Min distance: "+(string)(stopLevel*point), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
         if(!isBuyMode && (sl_val - price_val) < stopLevel * point)
           {
            MessageBox("SL is too close for Sell Market. Entry: "+DoubleToString(price_val,Digits())+", SL: "+DoubleToString(sl_val,Digits())+". Min distance: "+(string)(stopLevel*point), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
        }
      if(tp_val != 0.0)
        {
         if(isBuyMode && (tp_val - price_val) < stopLevel * point)
           {
            MessageBox("TP is too close for Buy Market. Entry: "+DoubleToString(price_val,Digits())+", TP: "+DoubleToString(tp_val,Digits())+". Min distance: "+(string)(stopLevel*point), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
         if(!isBuyMode && (price_val - tp_val) < stopLevel * point)
           {
            MessageBox("TP is too close for Sell Market. Entry: "+DoubleToString(price_val,Digits())+", TP: "+DoubleToString(tp_val,Digits())+". Min distance: "+(string)(stopLevel*point), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
        }
      // MQL4のOrderSendでは成行の場合、price引数は0を指定
      price_val = 0;
     }
   else // Limit/Stop Order
     {
      price_val = entryPriceValue; // 指値/逆指値の指定価格
      if(price_val <= 0)
        {
         MessageBox("Invalid Limit/Stop Price.", "Order Error", MB_OK | MB_ICONERROR);
         return;
        }

      double currentAsk = MarketInfo(Symbol(), MODE_ASK);
      double currentBid = MarketInfo(Symbol(), MODE_BID);

      if(isBuyMode)
        {
         // Buy Stop/Limit
         if(price_val < currentAsk - stopLevel * point)
            orderType_val = OP_BUYLIMIT; // 現在価格より十分下に指定 -> Buy Limit
         else
            if(price_val > currentAsk + stopLevel * point)
               orderType_val = OP_BUYSTOP;    // 現在価格より十分上に指定 -> Buy Stop
            else
              {
               MessageBox("Buy Limit/Stop price is too close to current Ask price. Price: "+DoubleToString(price_val,Digits()), "Order Error", MB_OK | MB_ICONERROR);
               return;
              }
         arrow_color = clrBlue;
        }
      else
        {
         // Sell Stop/Limit
         if(price_val > currentBid + stopLevel * point)
            orderType_val = OP_SELLLIMIT; // 現在価格より十分上に指定 -> Sell Limit
         else
            if(price_val < currentBid - stopLevel * point)
               orderType_val = OP_SELLSTOP;   // 現在価格より十分下に指定 -> Sell Stop
            else
              {
               MessageBox("Sell Limit/Stop price is too close to current Bid price. Price: "+DoubleToString(price_val,Digits()), "Order Error", MB_OK | MB_ICONERROR);
               return;
              }
         arrow_color = clrRed;
        }
      // SL/TPのストップレベルチェック (指値/逆指値の場合、エントリー価格基準)
      if(sl_val != 0.0)
        {
         if(isBuyMode && (price_val - sl_val) < stopLevel * point)   // Buy Limit/Stop
           {
            MessageBox("SL is too close for Buy Pending. Entry: "+DoubleToString(price_val,Digits())+", SL: "+DoubleToString(sl_val,Digits()), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
         if(!isBuyMode && (sl_val - price_val) < stopLevel * point)   // Sell Limit/Stop
           {
            MessageBox("SL is too close for Sell Pending. Entry: "+DoubleToString(price_val,Digits())+", SL: "+DoubleToString(sl_val,Digits()), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
        }
      if(tp_val != 0.0)
        {
         if(isBuyMode && (tp_val - price_val) < stopLevel * point)   // Buy Limit/Stop
           {
            MessageBox("TP is too close for Buy Pending. Entry: "+DoubleToString(price_val,Digits())+", TP: "+DoubleToString(tp_val,Digits()), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
         if(!isBuyMode && (price_val - tp_val) < stopLevel * point)   // Sell Limit/Stop
           {
            MessageBox("TP is too close for Sell Pending. Entry: "+DoubleToString(price_val,Digits())+", TP: "+DoubleToString(tp_val,Digits()), "Order Error", MB_OK | MB_ICONERROR);
            return;
           }
        }
     }

   int ticket = OrderSend(Symbol(), orderType_val, lot_val,
                          price_val, // 成行の場合は0, 指値/逆指値の場合は指定価格
                          3,        // スリッページ (成行のみ有効)
                          sl_val, tp_val, comment_val, MAGIC_NUMBER, 0, // expirationは0で無期限
                          arrow_color);

   if(ticket > 0)
     {
      string orderTypeStr = "Unknown";
      switch(orderType_val)
        {
         case OP_BUY:
            orderTypeStr = "Buy Market";
            break;
         case OP_SELL:
            orderTypeStr = "Sell Market";
            break;
         case OP_BUYLIMIT:
            orderTypeStr = "Buy Limit";
            break;
         case OP_SELLLIMIT:
            orderTypeStr = "Sell Limit";
            break;
         case OP_BUYSTOP:
            orderTypeStr = "Buy Stop";
            break;
         case OP_SELLSTOP:
            orderTypeStr = "Sell Stop";
            break;
        }
      string msg = StringFormat("Order placed successfully!\nType: %s\nTicket: %d\nSymbol: %s\nLots: %.2f\nPrice: %s\nSL: %s\nTP: %s",
                                orderTypeStr, ticket, Symbol(), lot_val,
                                (orderType_val == OP_BUY || orderType_val == OP_SELL) ? DoubleToString(OrderOpenPrice(),Digits()) : DoubleToString(price_val,Digits()),
                                sl_val == 0.0 ? "None" : DoubleToString(sl_val,Digits()),
                                tp_val == 0.0 ? "None" : DoubleToString(tp_val,Digits())
                               );
      Print(msg);
      //MessageBox(msg, "Order Result", MB_OK | MB_ICONINFORMATION);
     }
   else
     {
      int errorCode = GetLastError();
      string errorMsg = StringFormat("Order placement failed.\nError: %d (%s)\nLot: %.2f, Price: %.5f, SL: %.5f, TP: %.5f, Type: %d",
                                     errorCode, ErrorDescription(errorCode), lot_val, price_val, sl_val, tp_val, orderType_val);
      Print(errorMsg);
      MessageBox(errorMsg, "Order Error", MB_OK | MB_ICONERROR);
     }
  }
//+------------------------------------------------------------------+
