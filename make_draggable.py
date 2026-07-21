import sys
import re

def patch_file():
    filepath = r"d:\all api apks\bineto_f+l\New folder\New folder\binteo\lib\webview_page.dart"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add state variables
    state_injection = """class _MyWebViewPageState extends State<MyWebViewPage> {
  double _fabX = 0;
  double _fabY = 0;
  bool _fabPositionInitialized = false;"""
    content = content.replace("class _MyWebViewPageState extends State<MyWebViewPage> {", state_injection, 1)

    # Inject initialization into build
    build_injection = """Widget build(BuildContext context) {
      if (!_fabPositionInitialized) {
        final size = MediaQuery.of(context).size;
        _fabX = size.width - 48.0 - 8.0; // 48 is mini FAB size, 8 is right padding
        _fabY = size.height - 48.0 - 90.0; // 90 is bottom padding
        _fabPositionInitialized = true;
      }
      return PopScope("""
    content = content.replace("Widget build(BuildContext context) {\n      return PopScope(", build_injection, 1)

    # Find and extract the FloatingActionButton widget block
    fab_start = content.find("floatingActionButton: Padding(")
    
    # We need to find the end of the FloatingActionButton block to remove it.
    # It ends with `)),`
    fab_end = content.find("));", fab_start)
    if fab_start == -1 or fab_end == -1:
        print("Could not find FAB block.")
        return
        
    fab_block = content[fab_start:fab_end]
    
    # Extract just the FloatingActionButton part
    inner_fab_start = fab_block.find("FloatingActionButton(")
    inner_fab_end = fab_block.rfind("),") + 1 # The closing parenthesis of FloatingActionButton
    inner_fab_code = fab_block[inner_fab_start:inner_fab_end]
    
    # Replace the Scaffold body to be a Stack with the draggable FAB
    new_scaffold = f"""child: Scaffold(
         body: Stack(
           children: [
             _buildBody(),
             Positioned(
               left: _fabX,
               top: _fabY,
               child: GestureDetector(
                 onPanUpdate: (details) {{
                   setState(() {{
                     _fabX += details.delta.dx;
                     _fabY += details.delta.dy;
                     
                     // Constrain within screen bounds
                     final size = MediaQuery.of(context).size;
                     if (_fabX < 0) _fabX = 0;
                     if (_fabY < 0) _fabY = 0;
                     if (_fabX > size.width - 48) _fabX = size.width - 48;
                     if (_fabY > size.height - 48) _fabY = size.height - 48;
                   }});
                 }},
                 child: {inner_fab_code},
               ),
             ),
           ],
         )"""
         
    # Replace old Scaffold structure
    old_scaffold_start = content.find("child: Scaffold(")
    old_scaffold_end = fab_end # ends at the `));` which is actually `)) ;` or similar
    
    old_scaffold_block = content[old_scaffold_start:old_scaffold_end]
    content = content.replace(old_scaffold_block, new_scaffold)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("Patched draggable FAB successfully.")

patch_file()
