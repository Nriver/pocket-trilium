import os
import json
import re

# 配置部分
DRY_RUN = True  # 设置为 True 表示干运行，False 表示实际操作
PROJECT_DIR = '../'  # 项目根目录
ARB_DIR = os.path.join(PROJECT_DIR, 'lib/l10n')  # ARB 文件目录（默认为 lib/l10n）
EXCLUDE_DIRS = ['lib/I10n']  # 排除扫描的目录

# 获取所有的Dart文件
def get_dart_files(project_dir):
    dart_files = []
    for root, dirs, files in os.walk(project_dir):
        # 排除掉 'lib/I10n' 目录
        dirs[:] = [d for d in dirs if os.path.join(root, d) not in EXCLUDE_DIRS]
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))
    return dart_files

# 获取所有的ARB文件
def get_arb_files(arb_dir):
    arb_files = []
    for file in os.listdir(arb_dir):
        if file.endswith('.arb'):
            arb_files.append(os.path.join(arb_dir, file))
    return arb_files

# 解析ARB文件，返回键值对
def parse_arb_file(arb_file):
    with open(arb_file, 'r', encoding='utf-8') as f:
        return json.load(f)

# 保存修改后的ARB文件
def save_arb_file(arb_file, data):
    with open(arb_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# 获取代码中所有可能引用翻译的键
def find_keys_in_dart_files(dart_files):
    translation_keys = set()

    for dart_file in dart_files:
        with open(dart_file, 'r', encoding='utf-8') as f:
            content = f.read()
            # 查找所有字符串内容，假设翻译key会作为字符串出现在代码中
            # 简单查找出现过的单词（我们认为翻译键是类似于单词的形式）
            keys = re.findall(r'\b[a-zA-Z0-9_]+\b', content)
            translation_keys.update(keys)
    
    return translation_keys

# 检查ARB文件中未被使用的翻译
def check_unused_translations(arb_files, dart_files):
    used_keys = find_keys_in_dart_files(dart_files)
    unused_translations = {}

    for arb_file in arb_files:
        arb_data = parse_arb_file(arb_file)
        for key, value in arb_data.items():
            # 检查键是否被使用
            if key not in used_keys:
                if arb_file not in unused_translations:
                    unused_translations[arb_file] = []
                unused_translations[arb_file].append(key)
    
    return unused_translations

# 删除未使用的翻译
def delete_unused_translations(arb_file, unused_keys):
    arb_data = parse_arb_file(arb_file)
    for key in unused_keys:
        if key in arb_data:
            del arb_data[key]
            print(f"删除翻译键：{key}，来自文件：{arb_file}")
    
    save_arb_file(arb_file, arb_data)

# 打印未使用的翻译
def print_unused_translations(unused_translations, dry_run=False):
    if not unused_translations:
        print("没有未使用的翻译！")
    else:
        for arb_file, keys in unused_translations.items():
            print(f"文件 {arb_file} 中未使用的翻译键:")
            for key in keys:
                print(f"  - {key}")
                
            # 如果是dry-run模式，不执行删除，只显示
            if dry_run:
                print(f"\n[Dry-run模式] 未使用的翻译已列出，但没有实际删除。\n")
            else:
                print(f"\n[实际模式] 正在删除未使用的翻译...\n")
                delete_unused_translations(arb_file, keys)

# 主程序
def main():
    dart_files = get_dart_files(PROJECT_DIR)
    arb_files = get_arb_files(ARB_DIR)
    
    unused_translations = check_unused_translations(arb_files, dart_files)
    
    print_unused_translations(unused_translations, dry_run=DRY_RUN)

if __name__ == '__main__':
    main()
