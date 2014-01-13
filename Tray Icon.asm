include masm32rt.inc
include debug2.inc
includelib debug2.lib

ICON_DIC            equ     1
ICON_RED            equ     2
ICON_YELLOW         equ     3
ICON_GREEN          equ     4
ID_TIMER            equ     5
IDM_EXIT            equ     6
IDM_DIC_NEW         equ     7
IDM_START           equ     8
IDM_STOP            equ     9

WM_SHELLNOTIFY      equ     WM_USER + 5
    
.data
szClsTrayTut        BYTE    "TRAY_TUTORIAL", 0
szAppName           BYTE    "DiC Tray Tutorial", 0
szDic               BYTE    "DiC New Topics", 0
szStart             BYTE    "Start Traffic Lights", 0
szStop              BYTE    "Stop Traffic Lights", 0
szExit              BYTE    "Exit", 0
szDiCNewTopics      BYTE    "http://www.dreamincode.net/forums/index.php?app=core&module=search&do=active", 0
szOpen              BYTE    "Open", 0
szMutex             BYTE    "Global\TrayTut", 0
szRunning           BYTE    "Already running!", 0

.data?
hInst               DWORD   ?
hRed                DWORD   ?
hYellow             DWORD   ?
hGreen              DWORD   ?
hDiC                DWORD   ?
hPopupMenu          DWORD   ?
nid                 NOTIFYICONDATA <?>
dwCurrentIcon       DWORD   ?
hMutex              DWORD   ?
dwTimerRunning      DWORD   ?

.code
TrayIcon:
    invoke  CreateMutex, NULL, FALSE, offset szMutex
    mov     hMutex, eax
    
    invoke  GetLastError
    cmp     eax, ERROR_ALREADY_EXISTS
    jne     GoAhead
    invoke  MessageBox, HWND_DESKTOP, offset szRunning, NULL, MB_ICONEXCLAMATION
    jmp     Done
    
GoAhead:
    call    StartUp
    
Done:
    invoke  CloseHandle, hMutex
    invoke  ExitProcess, eax

StartUp proc
LOCAL   msg:MSG
LOCAL   wc:WNDCLASSEX

    invoke  memfill, addr wc, sizeof WNDCLASSEX, 0
    invoke  GetModuleHandle, NULL
    mov     hInst, eax
    
    mov     wc.cbSize, sizeof WNDCLASSEX
    mov     wc.hInstance, eax
    mov     wc.lpszClassName, offset szClsTrayTut
    mov     wc.lpfnWndProc, offset WndProc
    invoke  RegisterClassEx, addr wc
    
    xor     ecx, ecx
    invoke  CreateWindowEx, ecx, offset szClsTrayTut, ecx, ecx, ecx, ecx, ecx, ecx, HWND_MESSAGE, ecx, hInst, ecx
   
    .while TRUE
        invoke  GetMessage, addr msg, NULL, 0, 0
        .break .if !eax
        invoke  TranslateMessage, addr msg
        invoke  DispatchMessage, addr msg
    .endw
    mov     eax, msg.message       
    ret
StartUp endp

WndProc proc uses esi edi hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
LOCAL   pt:POINT

    mov		eax,uMsg
    .if eax==WM_CREATE
        mov     esi, hInst
        mov     dwCurrentIcon, ICON_GREEN
        mov     dwTimerRunning, FALSE

        invoke  LoadImage, esi, ICON_RED, IMAGE_ICON, 0, 0, NULL
        mov     hRed, eax

        invoke  LoadImage, esi, ICON_YELLOW, IMAGE_ICON, 0, 0, NULL
        mov     hYellow, eax

        invoke  LoadImage, esi, ICON_GREEN, IMAGE_ICON, 0, 0, NULL
        mov     hGreen, eax

        invoke  LoadImage, esi, ICON_DIC, IMAGE_ICON, 0, 0, NULL
        mov     hDiC, eax

        invoke  CreatePopupMenu
        mov     hPopupMenu, eax
        mov     edi, eax
        invoke  AppendMenu, eax, MF_STRING, IDM_DIC_NEW, offset szDic
        invoke  AppendMenu, edi, MF_STRING, IDM_START, offset szStart
        invoke  AppendMenu, edi, MF_STRING, IDM_EXIT, offset szExit
        
        mov     nid.cbSize, sizeof NOTIFYICONDATA
        push    hWin
        pop     nid.hwnd
        mov     nid.uID, 0
        mov     nid.uFlags, NIF_ICON or NIF_MESSAGE or NIF_TIP
        mov     nid.uCallbackMessage, WM_SHELLNOTIFY
        push    hDiC
        pop     nid.hIcon
        invoke  lstrcpy, offset nid.szTip, offset szAppName
        invoke  Shell_NotifyIcon, NIM_ADD, offset nid
        
    .elseif eax==WM_COMMAND
        mov		edx,wParam
        movzx	eax,dx
        shr		edx,16
        .if edx==BN_CLICKED
            .if eax == IDM_DIC_NEW
                invoke	ShellExecute, NULL, offset szOpen, offset szDiCNewTopics, NULL, NULL, SW_SHOWNORMAL or SW_RESTORE
                .if dwTimerRunning == TRUE
                    mov     ax, BN_CLICKED
                    ror     eax, 16
                    mov     ax, IDM_STOP
                    invoke  SendMessage, hWin, WM_COMMAND, eax, NULL           
                    push    hDiC
                    pop     nid.hIcon
                    ;invoke  Shell_NotifyIcon, NIM_MODIFY, offset nid
                .endif
                   
            .elseif eax == IDM_START
                invoke  ModifyMenu, hPopupMenu, 1, MF_BYPOSITION, IDM_STOP, offset szStop
                invoke  SetTimer, hWin, ID_TIMER, 500, NULL
                mov     dwTimerRunning, TRUE
                
            .elseif eax == IDM_STOP
                invoke  ModifyMenu, hPopupMenu, 1, MF_BYPOSITION, IDM_START, offset szStart
                invoke  KillTimer, hWin, ID_TIMER
                mov     dwTimerRunning, FALSE
                
            .elseif eax==IDM_EXIT
                invoke  Shell_NotifyIcon, NIM_DELETE, offset nid
                invoke  SendMessage, hWin, WM_CLOSE, 0, 0
            .endif
        .endif

    .elseif eax == WM_SHELLNOTIFY
        .if wParam == 0
            .if lParam == WM_RBUTTONDOWN or WM_RBUTTONUP
                invoke  GetCursorPos, ADDR pt
                invoke  SetForegroundWindow, hWin
                invoke  TrackPopupMenuEx, hPopupMenu, TPM_LEFTALIGN or TPM_LEFTBUTTON, pt.x, pt.y, hWin, 0
                invoke  PostMessage, hWin, WM_NULL, 0, 0
            .endif
        .endif		
        
    .elseif eax == WM_TIMER
        .if dwCurrentIcon == ICON_RED
            push    hGreen
            pop     nid.hIcon
            mov     dwCurrentIcon, ICON_GREEN
            
        .elseif dwCurrentIcon == ICON_YELLOW
            push    hRed
            pop     nid.hIcon
            mov     dwCurrentIcon, ICON_RED
            
        .else
            push    hYellow
            pop     nid.hIcon
            mov     dwCurrentIcon, ICON_YELLOW
        .endif
        invoke  Shell_NotifyIcon, NIM_MODIFY, offset nid
       
    .elseif eax==WM_CLOSE 
        invoke  DestroyIcon, hRed
        invoke  DestroyIcon, hYellow
        invoke  DestroyIcon, hGreen
        invoke  DestroyIcon, hDiC
        invoke  DestroyMenu, hPopupMenu
        invoke  KillTimer, hWin, ID_TIMER
        invoke  DestroyWindow, hWin
        
    .elseif eax==WM_DESTROY
        invoke PostQuitMessage,NULL
        
    .else
        invoke DefWindowProc,hWin,uMsg,wParam,lParam
        ret
    .endif
    xor    eax,eax
    ret

WndProc endp

end TrayIcon