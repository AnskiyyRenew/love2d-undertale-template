// Windows 下使用 cl 编译：
// cl /O2 /LD /EHsc /Fe:cpp.dll rectangulation.cpp /utf-8
#include <vector>
#include <cstdint>
#include <algorithm>
#include <stack>
#include <cstring>
#include <iostream>
#include <memory>

// 定义矩形数据结构
struct Rect {
    int x;
    int y;
    int w;
    int h;
};

// 矩形列表结构
struct RectList {
    int num_rects;
    Rect* rects;
};

// 高效内存管理器
class MemoryPool {
public:
    MemoryPool(size_t block_size, size_t preallocate)
        : block_size(block_size) {
        for (size_t i = 0; i < preallocate; ++i) {
            void* block = malloc(block_size);
            free_blocks.push_back(block);
        }
    }
    
    ~MemoryPool() {
        for (void* block : free_blocks) free(block);
        for (void* block : allocated_blocks) free(block);
    }
    
    void* allocate() {
        if (!free_blocks.empty()) {
            void* block = free_blocks.back();
            free_blocks.pop_back();
            allocated_blocks.push_back(block);
            return block;
        }
        void* block = malloc(block_size);
        allocated_blocks.push_back(block);
        return block;
    }
    
    void deallocate(void* block) {
        auto it = std::find(allocated_blocks.begin(), allocated_blocks.end(), block);
        if (it != allocated_blocks.end()) {
            allocated_blocks.erase(it);
            free_blocks.push_back(block);
        }
    }

private:
    size_t block_size;
    std::vector<void*> free_blocks;
    std::vector<void*> allocated_blocks;
};

// 全局内存池
MemoryPool rect_pool(sizeof(RectList), 10);
MemoryPool rect_array_pool(sizeof(Rect) * 500, 5); // 预分配500个矩形的空间

// 计算二维数组前缀和
inline void compute_prefix_sum(const uint8_t* grid, int width, int height, uint32_t* prefix) {
    // 初始化第一行和第一列为0
    for (int i = 0; i <= height; ++i) {
        prefix[i * (width + 1)] = 0;
    }
    for (int j = 0; j <= width; ++j) {
        prefix[j] = 0;
    }

    // 标准二维前缀和计算 (行1..height, 列1..width)
    for (int i = 1; i <= height; ++i) {
        for (int j = 1; j <= width; ++j) {
            const int grid_idx = (i - 1) * width + (j - 1);  // 对应网格中的位置
            prefix[i * (width + 1) + j] = 
                (grid[grid_idx] == 2 ? 1 : 0)   // 当前网格点
                + prefix[(i - 1) * (width + 1) + j]   // 上方前缀
                + prefix[i * (width + 1) + (j - 1)]   // 左侧前缀
                - prefix[(i - 1) * (width + 1) + (j - 1)];  // 左上角重叠部分
        }
    }
}

inline int compute_rect_score(const uint32_t* prefix, int width,
                              int top_row, int bottom_row, 
                              int left_col, int right_col) {
    // 使用标准二维前缀和矩形区域公式
    return prefix[(bottom_row + 1) * (width + 1) + right_col + 1]
         - prefix[top_row * (width + 1) + right_col + 1]
         - prefix[(bottom_row + 1) * (width + 1) + left_col]
         + prefix[top_row * (width + 1) + left_col];
}

// 矩形扩展算法（核心算法）
inline Rect global_expand_rect(const uint8_t* grid, int width, int height, const uint32_t* prefix) {
    std::vector<int> heights(width + 1, 0);  // 高度数组 (+1 for sentinel)
    std::vector<int> stack;
    stack.reserve(width + 2);
    
    int max_score = 0;
    Rect best_rect = {0, 0, 0, 0};

    for (int row = 0; row < height; ++row) {
        // 更新高度数组（当前行连续向上延伸长度）
        for (int col = 0; col < width; ++col) {
            const int idx = row * width + col;
            heights[col] = grid[idx] != 0 ? heights[col] + 1 : 0;
        }
        
        // 添加行尾哨兵
        heights[width] = 0;
        stack.clear();
        stack.push_back(-1);  // 左边界哨兵

        for (int j = 0; j <= width; ++j) {
            // 维护单调递增栈
            while (stack.size() > 1 && heights[j] < heights[stack.back()]) {
                int top_idx = stack.back();
                stack.pop_back();
                
                int left_bound = stack.back() + 1;
                int rect_height = heights[top_idx];
                int rect_width = j - left_bound;
                
                // 仅处理有效矩形
                if (rect_width > 0 && rect_height > 0) {
                    int top_row = row - rect_height + 1;
                    int bottom_row = row;
                    
                    // 计算矩形区域内未访问点数量(值为2的点)
                    int score = compute_rect_score(
                        prefix, width,
                        top_row, bottom_row,
                        left_bound, j - 1  // 矩形右边界=j-1
                    );
                    
                    // 更新最佳矩形
                    if (score > max_score) {
                        max_score = score;
                        best_rect = {
                            left_bound,    // x (列索引)
                            top_row,       // y (行索引)
                            rect_width,    // 宽度
                            rect_height    // 高度
                        };
                    }
                }
            }
            stack.push_back(j);
        }
    }
    
    return best_rect;
}

// 主处理函数
extern "C" __declspec(dllexport) RectList* rectangulate_grid(uint8_t* input_grid, int width, int height) {
    // 优化前缀和存储 (height+1) x (width+1)
    std::vector<uint32_t> prefix((width + 1) * (height + 1), 0);
    
    // 使用内存池分配结果
    auto result = static_cast<RectList*>(rect_pool.allocate());
    std::vector<Rect> rects;
    rects.reserve(width * height / 10); // 预分配空间
    
    // 主处理循环
    while (true) {
        compute_prefix_sum(input_grid, width, height, prefix.data());
        Rect rect = global_expand_rect(input_grid, width, height, prefix.data());
        
        // 结束条件
        if (rect.w <= 0 || rect.h <= 0) break;
        
        rects.push_back(rect);
        
        // 更新网格状态
        for (int y = rect.y; y < rect.y + rect.h; ++y) {
            for (int x = rect.x; x < rect.x + rect.w; ++x) {
                const int idx = y * width + x;
                if (input_grid[idx] == 2) {
                    input_grid[idx] = 1;
                }
            }
        }
    }
    
    // 复制结果到输出结构
    const size_t rects_size = rects.size() * sizeof(Rect);
    result->rects = static_cast<Rect*>(rect_array_pool.allocate());
    memcpy(result->rects, rects.data(), rects_size);
    result->num_rects = rects.size();
    
    return result;
}

extern "C" __declspec(dllexport) RectList* rectangulate(const uint8_t* image_data, int width, int height) {
    // 创建本地网格副本
    uint8_t* local_grid = static_cast<uint8_t*>(malloc(width * height));

    // 转换输入网格格式
    for (int i = 0; i < height; ++i) {
        for (int j = 0; j < width; ++j) {
            const int idx = i * width + j;
            local_grid[idx] = (image_data[idx * 4 + 3] != 0) ? 2 : 0;
        }
    }
    
    auto result = rectangulate_grid(local_grid, width, height);
    free(local_grid);
    return result;
}

// 释放函数
extern "C" __declspec(dllexport) void free_rect_list(RectList* list) {
    rect_array_pool.deallocate(list->rects);
    rect_pool.deallocate(list);
}