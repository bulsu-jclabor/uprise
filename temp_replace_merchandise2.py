from pathlib import Path
import re

path = Path('lib/screens/web/org/org_merchandise.dart')
text = path.read_text().replace('\r\n', '\n')
old = '''  Widget _buildToolbar(bool isMobile, double fieldWidth) {
    final searchField = SizedBox(
      width: fieldWidth,
      height: 40,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentPage = 1;
        }),
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search orders...',
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
        ),
      ),
    );

    final controls = [
      _FilterDropdown(
        value: _statusFilter,
        items: _statusFilters,
        hint: 'Status',
        icon: Icons.tune_rounded,
        onChanged: (v) => setState(() {
          _statusFilter = v!;
          _currentPage = 1;
        }),
      ),
    ];

    return Padding(
      padding: EdgeInsets.zero,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAxisAlignment.center,
        children: [
        ],
      ),
    );
  }
'''
new = '''  Widget _buildToolbar(bool isMobile, double fieldWidth) {
    final searchField = SizedBox(
      width: fieldWidth,
      height: 40,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentPage = 1;
        }),
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search orders...',
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
        ),
      ),
    );

    final controls = [
      _FilterDropdown(
        value: _statusFilter,
        items: _statusFilters,
        hint: 'Status',
        icon: Icons.tune_rounded,
        onChanged: (v) => setState(() {
          _statusFilter = v!;
          _currentPage = 1;
        }),
      ),
    ];

    return Padding(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 980) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: controls
                      .expand((widget) => [widget, const SizedBox(width: 10)])
                      .toList()
                    ..removeLast(),
                ),
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAxisAlignment.center,
            children: [searchField, ...controls],
          );
        },
      ),
    );
  }
'''
if old not in text:
    raise SystemExit('Existing broken toolbar block not found')
path.write_text(text.replace(old, new, 1))
print('updated')
