#include <windows.h>
#include <gdiplus.h>
#include <vector>
#include <algorithm>
#include <chrono>
#include <memory>

const std::vector<bool> SaveAndQuitPattern = {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,0,0,1};
const std::vector<bool> CreateNewPattern = {0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,0,1,0,1,0,0,1,1,1,0,0,1,0,0,0,1,0,0,0,0,0,0};
const std::vector<bool> CreateNewWorldPattern = {0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,0,1,0,1,0,0,1,1,1,0,0,1,0,0,0,1,0,0,0,0,0,1};
const std::vector<bool> GameSettingsPattern = {1,0,0,1,1,0,0,1,1,1,0,0,1,1,0,1,0,0,0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,1,1,1,0,1,0,1,1,1,1};
const std::vector<bool> PlayPattern = {1,1,1,1,0,0,1,0,0,0,1,1,1,0,0,1,0,0,0,1};
const std::vector<std::vector<bool>> textPatterns = {SaveAndQuitPattern, CreateNewPattern, CreateNewWorldPattern, GameSettingsPattern, PlayPattern};

struct Vec3 {
    int x, y, z;
};

int GetMCScale(int w, int h, bool applyDPI = false, int dpiScale = 1) {
    if (applyDPI) {
        w += 16 * dpiScale;
        h += 8 * dpiScale;
    }
    int x = 1 + (w - 394 + 0.8) / 375.3333; // approximate
    int y = 1 + (h - 290 - 1) / 250;

    return x < y ? x : y;
}

std::vector<int> GenerateKMPTable(const std::vector<bool>& pattern) {
    std::vector<int> table(pattern.size(), 0);
    int j = 0;
    for (size_t i = 1; i < pattern.size(); ++i) {
        if (pattern[i] == pattern[j]) {
            table[i] = ++j;
        } else {
            if (j != 0) {
                j = table[j - 1];
                --i;
            } else {
                table[i] = 0;
            }
        }
    }
    return table;
}

std::pair<int, int> KMPMatch(const std::vector<std::vector<bool>>& vector, const std::vector<bool>& pattern) {
    int patternWidth = pattern.size();
    std::vector<int> table = GenerateKMPTable(pattern);

    for (size_t y = 0; y < vector.size(); ++y) {
        const auto& row = vector[y];
        int j = 0;
        for (size_t i = 0; i < row.size();) {
            if (pattern[j] == row[i]) {
                ++i;
                ++j;
            }
            if (j == patternWidth) {
                return {i - j, y};
            } else if (i < row.size() && pattern[j] != row[i]) {
                if (j != 0) {
                    j = table[j - 1];
                } else {
                    ++i;
                }
            }
        }
    }
    return {-1, -1};
}

std::unique_ptr<Gdiplus::Bitmap> BitmapFromHWND(HWND hwnd) {
    if (IsIconic(hwnd))
        ShowWindow(hwnd, SW_RESTORE);

    int width, height;
    RECT rc;
    GetWindowRect(hwnd, &rc);
    width = rc.right - rc.left;
    height = rc.bottom - rc.top;

    HDC hdc = GetDC(hwnd);
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdc, width, height);
    HBITMAP hOldBitmap = (HBITMAP)SelectObject(memDC, hBitmap);

    PrintWindow(hwnd, memDC, PW_RENDERFULLCONTENT);

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

    std::unique_ptr<Gdiplus::Bitmap> pBitmap = BitmapFromHWND(hwnd);
    int mcWidth = pBitmap->GetWidth();
    int mcHeight = pBitmap->GetHeight();
    int mcScale = GetMCScale(mcWidth, mcHeight);
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
            } else if (pixelColor == 0xFFFF1313) { //skip to the chase
                if (foundAtIndices.empty()) {
                    code = 0;

                    pBitmap->UnlockBits(&bitmapData);
                    pBitmap.reset();
                    Gdiplus::GdiplusShutdown(gdiplusToken);
                    return 0;
                }
            }
        }
        if (hasFounded) {
            foundPixels.push_back(row);
            foundAtIndices.push_back(y);
        }
    }
    pBitmap->UnlockBits(&bitmapData);
    pBitmap.reset();
    Gdiplus::GdiplusShutdown(gdiplusToken);

    if (foundPixels.empty()) 
        return std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - start).count();

    int pIndex = -1;
    std::pair<int, int> result = {-1, -1};
    for (size_t i = 0; i < textPatterns.size(); i++) {
        result = KMPMatch(foundPixels, textPatterns[i]);

        if (result.first != -1) {
            pIndex = i + 1;
            break;
        }
    }

    code = pIndex;
    fx = result.first * mcScale;
    fy = foundAtIndices[result.second] - 30 * dpiScale;

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
    return duration;
}

extern "C" __declspec(dllexport) int GetShownCoordinates(HWND hwnd, Vec3* coordinates) {
    auto start = std::chrono::high_resolution_clock::now();

    Gdiplus::GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR gdiplusToken;
    Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

    std::unique_ptr<Gdiplus::Bitmap> pBitmap = BitmapFromHWND(hwnd);
    int mcWidth = pBitmap->GetWidth();
    int mcHeight = pBitmap->GetHeight();
    int searchWidth = mcWidth/3;
    int searchHeight = mcHeight/3;
    Gdiplus::BitmapData bitmapData;
    Gdiplus::Rect rect(0, 0, searchWidth, searchHeight);
    pBitmap->LockBits(&rect, Gdiplus::ImageLockModeRead, PixelFormat32bppARGB, &bitmapData);

    int startTextX = 0;
    int startTextY = 0;
    int streak = 0;
    int stride = bitmapData.Stride / sizeof(Gdiplus::ARGB);
    Gdiplus::ARGB* pixels = static_cast<Gdiplus::ARGB*>(bitmapData.Scan0);
    for (int y = 30; y < searchHeight; y++) {
        for (int x = 8; x < searchWidth; x++) {
            Gdiplus::ARGB pixelColor = pixels[y * stride + x];
            if (pixelColor == 0xFFFFFFFF) {
                if (!startTextX) {
                    startTextX = x;
                    startTextY = y;
                }
                streak++;
            } else if (streak < 4) {
                streak = 0;
            } else if (streak >= 4)
                break;
        }
        if (streak >= 4)
            break;
    }
    if (streak < 4)
        return 0;
    int mcScale = streak/4;
    startTextX += 44*mcScale;
    
    int coords[3] = {0, 0, 0};
    int coordIndex = 0;
    bool isSigned = false;

    while (startTextX < searchWidth) {
        unsigned int columnMask = 0b0;
        for (int dy = 0; dy < 7; dy++) {
            columnMask <<= 1;

            Gdiplus::ARGB pixelColor = pixels[(startTextY + dy * mcScale) * stride + startTextX];
            if (pixelColor == 0xFFFFFFFF)
                columnMask |= 0b1;
        }

        int digit = -1;
        switch (columnMask) {
            case 0b0111110: digit = 0; break;
            case 0b0000001: digit = 1; break;
            case 0b0100011: digit = 2; break;
            case 0b0100010: digit = 3; break;
            case 0b0001100: digit = 4; break;
            case 0b1110010: digit = 5; break;
            case 0b0011110: digit = 6; break;
            case 0b1100000: digit = 7; break;
            case 0b0110110: digit = 8; break;
            case 0b0110000: digit = 9; break;
            case 0b0001000: isSigned = true; break;
            case 0b0000011: 
                if (isSigned) coords[coordIndex] *= -1;
                if (++coordIndex > 2) startTextX = searchWidth;
                isSigned = false;
                break;
            default:
                if (coordIndex >= 2) startTextX = searchWidth;
                if (isSigned) coords[coordIndex] *= -1;
                break;
        }
        if (digit != -1)
            coords[coordIndex] = coords[coordIndex] * 10 + digit;

        startTextX += 6*mcScale;
    }
    pBitmap->UnlockBits(&bitmapData);
    pBitmap.reset();
    Gdiplus::GdiplusShutdown(gdiplusToken);

    coordinates->x = coords[0];
    coordinates->y = coords[1];
    coordinates->z = coords[2];

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
    return duration;
}