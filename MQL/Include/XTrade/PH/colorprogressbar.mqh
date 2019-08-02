//+------------------------------------------------------------------+
//|                                             ColorProgressBar.mqh |
//|                        Copyright 2012, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"

#include <Canvas\Canvas.mqh>
//+------------------------------------------------------------------+
//|  ����� ��������-����, �������� ����� �������                     |
//+------------------------------------------------------------------+
class CColorProgressBar :public CCanvas
  {
private:
   color             m_goodcolor,m_badcolor;    // "�������" � "������" �����
   color             m_backcolor,m_bordercolor; // ����� ���� � �����
   int               m_x;                       // X ���������� ������ �������� ���� 
   int               m_y;                       // Y ���������� ������ �������� ���� 
   int               m_width;                   // ������
   int               m_height;                  // ������
   int               m_borderwidth;             // ������� �����
   bool              m_passes[];                // ���������� ������������ ��������
   int               m_lastindex;               // ����� ���������� �������
public:
   //--- �����������/����������
                     CColorProgressBar();
                    ~CColorProgressBar(){ CCanvas::Destroy(); };
   //--- �������������
   bool              Create(const string name,int x,int y,int width,int height,ENUM_COLOR_FORMAT clrfmt);
   //--- ���������� ������� � ����
   void              Reset(void)                 { m_lastindex=0;     };
   //--- ���� ����, ����� � �����
   void              BackColor(const color clr)  { m_backcolor=clr;   };
   void              BorderColor(const color clr){ m_bordercolor=clr; };
   //---             ��������� ������������� ����� �� ���� color � ��� uint
   uint              uCLR(const color clr)          { return(XRGB((clr)&0x0FF,(clr)>>8,(clr)>>16));};
   //--- ������� ����� � �����
   void              BorderWidth(const int w) { m_borderwidth=w;      };
   //--- ������� ��������� ��� ��������� ������� � ��������-����
   void              AddResult(bool good);
   //--- ���������� ��������-���� �� �������
   void              Update(void);
  };
//+------------------------------------------------------------------+
//| �����������                                                      |
//+------------------------------------------------------------------+
CColorProgressBar::CColorProgressBar():m_lastindex(0),m_goodcolor(clrSeaGreen),m_badcolor(clrLightPink)
  {
//--- ������� ������ ������� �������� � �������
   ArrayResize(m_passes,5000,1000);
   ArrayInitialize(m_passes,0);
//---
  }
//+------------------------------------------------------------------+
//|  �������������                                                   |
//+------------------------------------------------------------------+
bool CColorProgressBar::Create(const string name,int x,int y,int width,int height,ENUM_COLOR_FORMAT clrfmt)
  {
   bool res=false;
//--- �������� ������������ ����� ��� �������� ������
   if(CCanvas::CreateBitmapLabel(name,x,y,width,height,clrfmt))
     {
      //--- �������� ������ � ������
      m_height=height;
      m_width=width;
      res=true;
     }
//--- ���������
   return(res);
  }
//+------------------------------------------------------------------+
//|  ���������� ����������                                           |
//+------------------------------------------------------------------+
void CColorProgressBar::AddResult(bool good)
  {
   m_passes[m_lastindex]=good;
//--- ������� ��� ���� ������������ ����� ������� ����� � ��������-����
   LineVertical(m_lastindex,m_borderwidth,m_height-m_borderwidth,uCLR(good?m_goodcolor:m_badcolor));
//--- ���������� �� �������
   CCanvas::Update();
//--- ���������� �������
   m_lastindex++;
   if(m_lastindex>=m_width) m_lastindex=0;
//---
  }
//+------------------------------------------------------------------+
//|  ���������� �����                                                |
//+------------------------------------------------------------------+
void CColorProgressBar::Update(void)
  {
//--- ������ ������ ����� ���
   CCanvas::Erase(CColorProgressBar::uCLR(m_bordercolor));
//--- �������� ������������� ������ ����
   CCanvas::FillRectangle(m_borderwidth,m_borderwidth,
                           m_width-m_borderwidth-1,
                           m_height-m_borderwidth-1,
                           CColorProgressBar::uCLR(m_backcolor));
//--- ������� ����
   CCanvas::Update();
  }
//+------------------------------------------------------------------+
