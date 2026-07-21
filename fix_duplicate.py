import sys

def fix_file():
    filepath = r"d:\all api apks\bineto_f+l\New folder\New folder\binteo\lib\webview_page.dart"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    start_idx = -1
    end_idx = -1
    
    # We want to remove lines from 1158 to 1372 (0-indexed: 1157 to 1371)
    # Let's verify line numbers:
    
    for i, line in enumerate(lines):
        if "onProgressChanged:" in line and "onLoadStop:" in lines[max(0, i-30):i]: # Wait, no.
            pass
            
    # Actually we can just slice lines
    # Lines 1158 to 1372 should be replaced by the progress function block.
    # The progress function block is:
    replacement = [
        "                       (controller, progressValue) {\n",
        "                     setState(() {\n",
        "                       progress = progressValue / 100.0;\n",
        "                       // Keep loading state active during page load - don't set to false here\n",
        "                     });\n",
        "                   },\n"
    ]
    
    # 0-indexed: 1157 is line 1158. 
    # 1371 is line 1372.
    # Wait! If I just delete lines 1158 (index 1157) through 1372 (index 1371) and insert `replacement`, I'll fix it.
    
    lines = lines[:1157] + replacement + lines[1372:]
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)
        
    print("Fixed file.")

fix_file()
