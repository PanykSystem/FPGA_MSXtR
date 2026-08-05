// FPGA MSXtR Updater - Win32 GUI (protocol not implemented yet)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <windowsx.h>
#include <commctrl.h>
#include <commdlg.h>
#include <cfgmgr32.h>
#include <setupapi.h>
#include <devguid.h>
#include <shlwapi.h>
#include <string>
#include <vector>
#include <cstdint>
#include <cstring>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "comdlg32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(linker, "/SUBSYSTEM:WINDOWS")
#pragma comment(linker, "/ENTRY:wWinMainCRTStartup")

#pragma pack(push, 1)
typedef struct {
    int8_t		signature[8];
    uint32_t	check_sum;
    uint8_t		reserved[4];
} FpgaMsxConfigFileHeader;

typedef struct {
    int8_t		target_id[4];
    uint32_t	image_size;
    uint8_t		major_version;
    uint8_t		minor_version;
    uint8_t		reserved[6];
} FpgaMsxConfigDataHeader;
#pragma pack(pop)

enum {
    ID_CB_TARGET = 1001,
    ID_ED_FILE,
    ID_BTN_FOLDER,
    ID_ED_CPU,
    ID_ED_VDP,
    ID_BTN_WRITE,
};

static const wchar_t WND_CLASS[] = L"FpgaMsxUpdaterWnd";
static const wchar_t WND_TITLE[] = L"FPGA MSXtR Updater v1.0";
static const size_t MAX_FILE_SIZE = 8 * 1024 * 1024;

static HWND g_hCbTarget = nullptr;
static HWND g_hEdFile = nullptr;
static HWND g_hBtnFolder = nullptr;
static HWND g_hEdCpu = nullptr;
static HWND g_hEdVdp = nullptr;
static HWND g_hBtnWrite = nullptr;
static HWND g_hTooltip = nullptr;

static std::vector<uint8_t> g_fileData;
static std::wstring g_fileFullPath;
static bool g_fileValid = false;

// -------- COM port enumeration --------
static void enumerate_com_ports( HWND hCombo ) {
    ComboBox_ResetContent( hCombo );
    HDEVINFO hDevInfo = SetupDiGetClassDevsW( &GUID_DEVCLASS_PORTS, nullptr, nullptr, DIGCF_PRESENT );
    if( hDevInfo == INVALID_HANDLE_VALUE ) {
        return;
    }
    SP_DEVINFO_DATA devInfo;
    devInfo.cbSize = sizeof( devInfo );
    for( DWORD i = 0; SetupDiEnumDeviceInfo( hDevInfo, i, &devInfo ); i++ ) {
        HKEY hKey = SetupDiOpenDevRegKey( hDevInfo, &devInfo, DICS_FLAG_GLOBAL, 0, DIREG_DEV, KEY_READ );
        if( hKey == INVALID_HANDLE_VALUE ) {
            continue;
        }
        wchar_t portName[64] = { 0 };
        DWORD sz = sizeof( portName );
        DWORD type = 0;
        if( RegQueryValueExW( hKey, L"PortName", nullptr, &type, (LPBYTE)portName, &sz ) == ERROR_SUCCESS ) {
            if( wcsncmp( portName, L"COM", 3 ) == 0 ) {
                ComboBox_AddString( hCombo, portName );
            }
        }
        RegCloseKey( hKey );
    }
    SetupDiDestroyDeviceInfoList( hDevInfo );
}

// -------- MFD file parser --------
static void set_edit_text( HWND h, const wchar_t *s ) {
    SetWindowTextW( h, s );
}

static void update_write_button() {
    bool comSelected = ComboBox_GetCurSel( g_hCbTarget ) != CB_ERR;
    EnableWindow( g_hBtnWrite, ( comSelected && g_fileValid ) ? TRUE : FALSE );
}

static void parse_mfd_file() {
    set_edit_text( g_hEdCpu, L"" );
    set_edit_text( g_hEdVdp, L"" );
    g_fileValid = false;

    if( g_fileData.size() > MAX_FILE_SIZE || g_fileData.size() < sizeof( FpgaMsxConfigFileHeader ) ) {
        set_edit_text( g_hEdCpu, L"Error" );
        set_edit_text( g_hEdVdp, L"Error" );
        update_write_button();
        return;
    }

    const uint8_t *p = g_fileData.data();
    const FpgaMsxConfigFileHeader *fh = reinterpret_cast<const FpgaMsxConfigFileHeader *>( p );
    if( memcmp( fh->signature, "FPGAMSXC", 8 ) != 0 ) {
        set_edit_text( g_hEdCpu, L"Error" );
        set_edit_text( g_hEdVdp, L"Error" );
        update_write_button();
        return;
    }

    // check_sum: sum of all ConfigData bytes
    uint32_t sum = 0;
    size_t offset = sizeof( FpgaMsxConfigFileHeader );
    std::wstring cpuVer = L"None";
    std::wstring vdpVer = L"None";
    bool structOk = true;

    while( offset < g_fileData.size() ) {
        if( offset + sizeof( FpgaMsxConfigDataHeader ) > g_fileData.size() ) {
            structOk = false;
            break;
        }
        const FpgaMsxConfigDataHeader *dh = reinterpret_cast<const FpgaMsxConfigDataHeader *>( p + offset );
        size_t blockSize = sizeof( FpgaMsxConfigDataHeader ) + dh->image_size;
        if( offset + blockSize > g_fileData.size() ) {
            structOk = false;
            break;
        }
        for( size_t i = 0; i < blockSize; i++ ) {
            sum += p[offset + i];
        }
        wchar_t verBuf[32];
        wsprintfW( verBuf, L"v%u.%u", dh->major_version, dh->minor_version );
        if( memcmp( dh->target_id, "MTRC", 4 ) == 0 ) {
            cpuVer = verBuf;
        }
        else if( memcmp( dh->target_id, "MTRV", 4 ) == 0 ) {
            vdpVer = verBuf;
        }
        else {
            structOk = false;
            break;
        }
        offset += blockSize;
    }

    if( !structOk || sum != fh->check_sum ) {
        set_edit_text( g_hEdCpu, L"Error" );
        set_edit_text( g_hEdVdp, L"Error" );
        update_write_button();
        return;
    }

    set_edit_text( g_hEdCpu, cpuVer.c_str() );
    set_edit_text( g_hEdVdp, vdpVer.c_str() );
    g_fileValid = true;
    update_write_button();
}

static bool load_file( const wchar_t *path ) {
    HANDLE h = CreateFileW( path, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr );
    if( h == INVALID_HANDLE_VALUE ) {
        return false;
    }
    LARGE_INTEGER sz;
    if( !GetFileSizeEx( h, &sz ) ) {
        CloseHandle( h );
        return false;
    }
    g_fileData.clear();
    if( sz.QuadPart > (LONGLONG)MAX_FILE_SIZE ) {
        // larger than 8MB -> treat as invalid
        CloseHandle( h );
        g_fileData.assign( MAX_FILE_SIZE + 1, 0 );
        return true;
    }
    g_fileData.resize( (size_t)sz.QuadPart );
    DWORD readBytes = 0;
    if( sz.QuadPart > 0 ) {
        if( !ReadFile( h, g_fileData.data(), (DWORD)sz.QuadPart, &readBytes, nullptr ) ) {
            CloseHandle( h );
            return false;
        }
    }
    CloseHandle( h );
    return true;
}

static void open_file_dialog( HWND hWnd ) {
    wchar_t path[MAX_PATH] = { 0 };
    OPENFILENAMEW ofn = { 0 };
    ofn.lStructSize = sizeof( ofn );
    ofn.hwndOwner = hWnd;
    ofn.lpstrFilter = L"MFD File (*.mfd)\0*.mfd\0All Files (*.*)\0*.*\0";
    ofn.lpstrFile = path;
    ofn.nMaxFile = MAX_PATH;
    ofn.lpstrDefExt = L"mfd";
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_EXPLORER;
    if( !GetOpenFileNameW( &ofn ) ) {
        return;
    }

    g_fileFullPath = path;
    const wchar_t *name = PathFindFileNameW( path );
    set_edit_text( g_hEdFile, name );

    // update tooltip text
    TOOLINFOW ti = { 0 };
    ti.cbSize = sizeof( ti );
    ti.hwnd = hWnd;
    ti.uId = (UINT_PTR)g_hEdFile;
    SendMessageW( g_hTooltip, TTM_GETTOOLINFOW, 0, (LPARAM)&ti );
    ti.lpszText = const_cast<wchar_t *>( g_fileFullPath.c_str() );
    SendMessageW( g_hTooltip, TTM_UPDATETIPTEXTW, 0, (LPARAM)&ti );

    if( !load_file( path ) ) {
        set_edit_text( g_hEdCpu, L"Error" );
        set_edit_text( g_hEdVdp, L"Error" );
        g_fileValid = false;
        update_write_button();
        return;
    }
    parse_mfd_file();
}

// -------- window creation --------
static void create_controls( HWND hWnd, HINSTANCE hInst ) {
    HFONT hFont = (HFONT)GetStockObject( DEFAULT_GUI_FONT );

    auto label = [&]( const wchar_t *text, int x, int y, int w, int h ) {
        HWND l = CreateWindowW( L"STATIC", text, WS_CHILD | WS_VISIBLE, x, y, w, h, hWnd, nullptr, hInst, nullptr );
        SendMessageW( l, WM_SETFONT, (WPARAM)hFont, TRUE );
    };

    label( L"Target",      20,  20,  80, 20 );
    label( L"Config File", 20,  55,  80, 20 );
    label( L"CPU Side",    20, 110,  80, 20 );
    label( L"VDP Side",    20, 140,  80, 20 );

    g_hCbTarget = CreateWindowW( L"COMBOBOX", L"", WS_CHILD | WS_VISIBLE | WS_TABSTOP | CBS_DROPDOWNLIST | WS_VSCROLL,
        110, 18, 200, 200, hWnd, (HMENU)ID_CB_TARGET, hInst, nullptr );
    SendMessageW( g_hCbTarget, WM_SETFONT, (WPARAM)hFont, TRUE );

    g_hEdFile = CreateWindowExW( WS_EX_CLIENTEDGE, L"EDIT", L"", WS_CHILD | WS_VISIBLE | ES_READONLY | ES_AUTOHSCROLL,
        110, 53, 200, 22, hWnd, (HMENU)ID_ED_FILE, hInst, nullptr );
    SendMessageW( g_hEdFile, WM_SETFONT, (WPARAM)hFont, TRUE );

    g_hBtnFolder = CreateWindowW( L"BUTTON", L"Folder", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
        320, 52, 70, 24, hWnd, (HMENU)ID_BTN_FOLDER, hInst, nullptr );
    SendMessageW( g_hBtnFolder, WM_SETFONT, (WPARAM)hFont, TRUE );

    g_hEdCpu = CreateWindowExW( WS_EX_CLIENTEDGE, L"EDIT", L"", WS_CHILD | WS_VISIBLE | ES_READONLY,
        110, 108, 200, 22, hWnd, (HMENU)ID_ED_CPU, hInst, nullptr );
    SendMessageW( g_hEdCpu, WM_SETFONT, (WPARAM)hFont, TRUE );

    g_hEdVdp = CreateWindowExW( WS_EX_CLIENTEDGE, L"EDIT", L"", WS_CHILD | WS_VISIBLE | ES_READONLY,
        110, 138, 200, 22, hWnd, (HMENU)ID_ED_VDP, hInst, nullptr );
    SendMessageW( g_hEdVdp, WM_SETFONT, (WPARAM)hFont, TRUE );

    g_hBtnWrite = CreateWindowW( L"BUTTON", L"Write", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
        400, 180, 100, 30, hWnd, (HMENU)ID_BTN_WRITE, hInst, nullptr );
    SendMessageW( g_hBtnWrite, WM_SETFONT, (WPARAM)hFont, TRUE );
    EnableWindow( g_hBtnWrite, FALSE );

    // LOGO area (placeholder)
    HWND hLogo = CreateWindowW( L"STATIC", L"LOGO", WS_CHILD | WS_VISIBLE | SS_CENTER | SS_CENTERIMAGE | WS_BORDER,
        440, 230, 120, 80, hWnd, nullptr, hInst, nullptr );
    SendMessageW( hLogo, WM_SETFONT, (WPARAM)hFont, TRUE );

    HWND hCopy = CreateWindowW( L"STATIC", L"Copyright 2026 HRA!", WS_CHILD | WS_VISIBLE | SS_RIGHT,
        380, 335, 200, 20, hWnd, nullptr, hInst, nullptr );
    SendMessageW( hCopy, WM_SETFONT, (WPARAM)hFont, TRUE );

    // Tooltip
    g_hTooltip = CreateWindowExW( 0, TOOLTIPS_CLASSW, nullptr, WS_POPUP | TTS_ALWAYSTIP,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        hWnd, nullptr, hInst, nullptr );
    TOOLINFOW ti = { 0 };
    ti.cbSize = sizeof( ti );
    ti.uFlags = TTF_IDISHWND | TTF_SUBCLASS;
    ti.hwnd = hWnd;
    ti.uId = (UINT_PTR)g_hEdFile;
    ti.lpszText = const_cast<wchar_t *>( L"" );
    SendMessageW( g_hTooltip, TTM_ADDTOOLW, 0, (LPARAM)&ti );

    enumerate_com_ports( g_hCbTarget );
}

static LRESULT CALLBACK wnd_proc( HWND hWnd, UINT msg, WPARAM wp, LPARAM lp ) {
    switch( msg ) {
    case WM_CREATE:
        create_controls( hWnd, ( (LPCREATESTRUCT)lp )->hInstance );
        return 0;
    case WM_COMMAND:
        switch( LOWORD( wp ) ) {
        case ID_BTN_FOLDER:
            open_file_dialog( hWnd );
            return 0;
        case ID_CB_TARGET:
            if( HIWORD( wp ) == CBN_SELCHANGE ) {
                update_write_button();
            }
            return 0;
        case ID_BTN_WRITE:
            // TODO: implement after protocol is fixed
            MessageBoxW( hWnd, L"Communication protocol is not implemented yet.", WND_TITLE, MB_OK | MB_ICONINFORMATION );
            return 0;
        }
        break;
    case WM_CTLCOLORSTATIC:
        if( (HWND)lp == g_hEdFile || (HWND)lp == g_hEdCpu || (HWND)lp == g_hEdVdp ) {
            SetBkColor( (HDC)wp, GetSysColor( COLOR_WINDOW ) );
            return (LRESULT)GetSysColorBrush( COLOR_WINDOW );
        }
        break;
    case WM_CLOSE:
        DestroyWindow( hWnd );
        return 0;
    case WM_DESTROY:
        PostQuitMessage( 0 );
        return 0;
    }
    return DefWindowProcW( hWnd, msg, wp, lp );
}

int WINAPI wWinMain( HINSTANCE hInst, HINSTANCE, LPWSTR, int nCmdShow ) {
    INITCOMMONCONTROLSEX icc = { sizeof( icc ), ICC_WIN95_CLASSES | ICC_STANDARD_CLASSES };
    InitCommonControlsEx( &icc );

    WNDCLASSEXW wc = { 0 };
    wc.cbSize = sizeof( wc );
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = wnd_proc;
    wc.hInstance = hInst;
    wc.hCursor = LoadCursor( nullptr, IDC_ARROW );
    wc.hbrBackground = (HBRUSH)( COLOR_BTNFACE + 1 );
    wc.lpszClassName = WND_CLASS;
    wc.hIcon = LoadIcon( nullptr, IDI_APPLICATION );
    wc.hIconSm = LoadIcon( nullptr, IDI_APPLICATION );
    if( !RegisterClassExW( &wc ) ) {
        return 1;
    }

    // adjust client area to 600x400
    RECT rc = { 0, 0, 600, 400 };
    DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
    AdjustWindowRect( &rc, style, FALSE );

    HWND hWnd = CreateWindowExW( 0, WND_CLASS, WND_TITLE, style,
        CW_USEDEFAULT, CW_USEDEFAULT, rc.right - rc.left, rc.bottom - rc.top,
        nullptr, nullptr, hInst, nullptr );
    if( !hWnd ) {
        return 1;
    }
    ShowWindow( hWnd, nCmdShow );
    UpdateWindow( hWnd );

    MSG msg;
    while( GetMessageW( &msg, nullptr, 0, 0 ) > 0 ) {
        if( !IsDialogMessageW( hWnd, &msg ) ) {
            TranslateMessage( &msg );
            DispatchMessageW( &msg );
        }
    }
    return (int)msg.wParam;
}
