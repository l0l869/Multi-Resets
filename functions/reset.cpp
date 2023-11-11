#include <windows.h>
#include <gdiplus.h>
#include <vector>
#include <algorithm>
#include <chrono>
#include <memory>

int GetMCScale(int w, int h, bool applyDPI = false, int dpiScale = 1) {
    if (applyDPI) {
        w += 16 * dpiScale;
        h += 8 * dpiScale;
    }
    int x = 1 + (w - 394 + 0.8) / 375.3333; // approximate
    int y = 1 + (h - 290 - 1) / 250;

    return x < y ? x : y;
}

// slow but watever
std::pair<int, int> FindPattern(const std::vector<std::vector<bool>>& vector, const std::vector<bool>& pattern) {
    int vectorHeight = vector.size();
    int vectorWidth = vector[0].size();
    int patternWidth = pattern.size();

    for (int y = 0; y < vectorHeight; y++) {
        auto it = std::search(vector[y].begin(), vector[y].end(), pattern.begin(), pattern.end());
        if (it != vector[y].end()) {
            int x = std::distance(vector[y].begin(), it);
            return {x, y};
        }
    }

    return {-1, -1};
}

std::unique_ptr<Gdiplus::Bitmap> BitmapFromHWND(HWND hwnd, bool clientOnly) {
    if (IsIconic(hwnd))
        ShowWindow(hwnd, SW_RESTORE);

    int width, height;
    RECT rc;
    clientOnly ? GetClientRect(hwnd, &rc) : GetWindowRect(hwnd, &rc);
    width = rc.right - rc.left;
    height = rc.bottom - rc.top;

    HDC hdc = GetDC(hwnd);
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdc, width, height);
    HBITMAP hOldBitmap = (HBITMAP)SelectObject(memDC, hBitmap);

    PrintWindow(hwnd, memDC, PW_CLIENTONLY + (clientOnly ? 1 : 0));

    std::unique_ptr<Gdiplus::Bitmap> pBitmap = std::make_unique<Gdiplus::Bitmap>(hBitmap, nullptr);

    SelectObject(memDC, hOldBitmap);
    DeleteObject(hBitmap);
    DeleteDC(memDC);
    ReleaseDC(hwnd, hdc);

    return pBitmap;
}

extern "C" __declspec(dllexport) int GetCurrentClick(HWND hwnd, int dpiScale, int& code, int& fx, int& fy) {
    auto start = std::chrono::high_resolution_clock::now();

    Gdiplus::GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR gdiplusToken;
    Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int mcWidth = rc.right - rc.left;
    int mcHeight = rc.bottom - rc.top;
    int mcScale = GetMCScale(mcWidth, mcHeight, true, dpiScale);

    std::unique_ptr<Gdiplus::Bitmap> pBitmap = BitmapFromHWND(hwnd, true);
    Gdiplus::BitmapData bitmapData;
    Gdiplus::Rect rect(0, 0, mcWidth, mcHeight);
    pBitmap->LockBits(&rect, Gdiplus::ImageLockModeRead, PixelFormat32bppARGB, &bitmapData);

    std::vector<int> foundAtIndices;
    std::vector<std::vector<bool>> foundPixels(0, std::vector<bool>(mcWidth, 0));
    for (int y = 30 * dpiScale; y < mcHeight; y += mcScale) {
        Gdiplus::ARGB* pixels = reinterpret_cast<Gdiplus::ARGB*>(bitmapData.Scan0) + y * bitmapData.Stride / sizeof(Gdiplus::ARGB);
        std::vector<bool> row(mcWidth / mcScale, false);
        bool hasFounded = false;

        for (int x = 0; x < mcWidth; x += mcScale) {
            Gdiplus::ARGB pixelColor = pixels[x];

            if (pixelColor == 0xFF4C4C4C) {
                hasFounded = true;
                row[x / mcScale] = true;
            }
        }
        if (hasFounded) {
            foundPixels.push_back(row);
            foundAtIndices.push_back(y);
        }
    }
    pBitmap->UnlockBits(&bitmapData);
    Gdiplus::GdiplusShutdown(gdiplusToken);

    const std::vector<bool> SaveAndQuitPattern = {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,0,0,1};
    const std::vector<bool> CreateNewPattern = {0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,0,1,0,1,0,0,1,1,1,0,0,1,0,0,0,1,0,0,0,0,0,0};
    const std::vector<bool> CreateNewWorldPattern = {0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,0,1,0,1,0,0,1,1,1,0,0,1,0,0,0,1,0,0,0,0,0,1};
    const std::vector<bool> GameSettingsPattern = {1,0,0,1,1,0,0,1,1,1,0,0,1,1,0,1,0,0,0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,1,1,1,0,1,0,1,1,1,1};
    const std::vector<std::vector<bool>> textPatterns = {SaveAndQuitPattern, CreateNewPattern, CreateNewWorldPattern, GameSettingsPattern};

    int pIndex = -1;
    std::pair<int, int> result = {-1, -1};
    for (int i = 0; i < textPatterns.size(); i++) {
        const std::vector<bool>& pattern = textPatterns[i];
        result = FindPattern(foundPixels, pattern);

        if (result.first != -1) {
            pIndex = i + 1;
            break;
        }
    }

    code = pIndex;
    fx = result.first * mcScale;
    fy = foundAtIndices[result.second] - 30 * dpiScale;

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    return duration;
}