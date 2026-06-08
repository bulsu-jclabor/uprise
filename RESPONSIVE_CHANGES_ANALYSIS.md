# Responsive Changes Analysis: org_event_proposals.dart

## File Overview
- **Path**: `lib/screens/web/org/org_event_proposals.dart`
- **Type**: Main web screen for event proposals management
- **Current Status**: Desktop-only layout with hardcoded values

---

## 1. BUILD METHOD - Line 503-517
**Current Structure**:
```
build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFFBFCFE),
    body: Column(
      children: [
        _buildStatsRow(),          // Line 508
        _buildToolbar(),           // Line 509
        const SizedBox(height: 16), // Line 510
        Expanded(child: _buildTable()),  // Line 511
        const SizedBox(height: 24), // Line 512
      ],
    ),
  );
}
```

**Changes Needed**:
- Add screen width detection at line 504-505 (before Scaffold)
- Pass `isMobile`, `isTablet` parameters to all helper methods
- Update all method signatures to accept these parameters
- Consider stacking widgets differently on mobile

---

## 2. STATS ROW - Lines 520-540
**Current Structure**:
```dart
Widget _buildStatsRow() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),  // LINE 523 - HARDCODED
    child: Row(children: [  // LINE 524 - Always Row
      _StatCard(...),
      const SizedBox(width: 14), // LINE 526, 529, 532, 535 - HARDCODED
      // 4 stat cards total
    ]),
  );
}
```

**Issues**:
- **Line 523**: Fixed padding `EdgeInsets.fromLTRB(28, 24, 28, 0)` - needs to be `(isMobile ? 16 : isTablet ? 20 : 28)`
- **Lines 526, 529, 532, 535**: Fixed spacing `SizedBox(width: 14)` between cards - needs responsive value
- **Line 524**: Always uses `Row` - should be `Column` on mobile, `Row` on desktop/tablet
- **Line 525-538**: All 4 _StatCard wrapped in `Expanded` - mobile may need single column layout or wrapping

**Changes Required**:
1. Add parameter: `Widget _buildStatsRow(bool isMobile, bool isTablet)`
2. Replace padding with: `isMobile ? 16.0 : isTablet ? 20.0 : 28.0`
3. Replace Row with conditional: `isMobile ? Column : Row`
4. Adjust SizedBox spacing: `isMobile ? 8.0 : 14.0` horizontally, add vertical spacing for mobile
5. Consider grid layout or single column on mobile

---

## 3. TOOLBAR - Lines 543-560
**Current Structure**:
```dart
Widget _buildToolbar() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),  // LINE 544 - HARDCODED
    child: Row(children: [  // LINE 545 - Always Row
      Expanded(
        child: SizedBox(
          height: 40,  // LINE 548 - FIXED HEIGHT
          child: TextField(...),
        ),
      ),
      const SizedBox(width: 10), // LINE 572, 575, 578 - HARDCODED
      _FilterDropdown(...),
      const SizedBox(width: 10),
      AdminExportButton(...),
      const SizedBox(width: 10),
      _ToolbarButton(...),
    ]),
  );
}
```

**Issues**:
- **Line 544**: Fixed padding - needs responsive
- **Line 548**: Fixed height `40` - may need adjustment on mobile
- **Line 545**: Always `Row` - should stack on mobile
- **Lines 572, 575, 578**: Fixed spacing `10` - needs responsive
- **Search field**: Width control with `Expanded` may work but spacing needs adjustment

**Changes Required**:
1. Add parameter: `Widget _buildToolbar(bool isMobile, bool isTablet)`
2. Replace padding: responsive value
3. Conditional layout: `isMobile ? Column : Row`
4. Replace spacing: `isMobile ? 8.0 : 10.0`
5. Wrap buttons in SingleChildScrollView on mobile or reduce button width
6. May need to hide/show certain buttons on mobile (Export button?)

---

## 4. TABLE CONTAINER - Lines 564-592
**Current Structure**:
```dart
Widget _buildTable() {
  return StreamBuilder<QuerySnapshot>(
    builder: (context, snapshot) {
      final filtered = _applyFilters(allDocs);
      final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
      final pageDocs = filtered.sublist(start, end);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),  // LINE 588 - HARDCODED
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Column(children: [
          _buildTableHeader(),        // LINE 597
          Expanded(child: ListView.builder(...)),  // LINE 599
          _buildFooter(...),          // LINE 606
        ]),
      );
    },
  );
}
```

**Issues**:
- **Line 588**: Fixed margin `horizontal: 28` - needs responsive
- **Line 595**: borderRadius `14` - may be too large on mobile
- Table header and rows need complete redesign for mobile

**Changes Required**:
1. Add parameter: `Widget _buildTable(bool isMobile, bool isTablet)`
2. Replace margin: responsive calculation
3. Adjust borderRadius on mobile
4. Pass parameters to _buildTableHeader(), _buildFooter()
5. May need card-based layout on mobile instead of table

---

## 5. TABLE HEADER - Lines 609-626
**Current Structure**:
```dart
Widget _buildTableHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),  // LINE 611 - HARDCODED
    decoration: const BoxDecoration(
      color: Color(0xFFF8F9FB),
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
    ),
    child: Row(children: [  // LINE 617 - Always Row
      Expanded(flex: 4, child: _headerCell('EVENT TITLE')),
      Expanded(flex: 2, child: _headerCell('CATEGORY')),
      Expanded(flex: 2, child: _headerCell('AUDIENCE')),
      Expanded(flex: 2, child: _headerCell('DATE')),
      Expanded(flex: 2, child: _headerCell('TIME')),
      Expanded(flex: 2, child: _headerCell('LOCATION')),
      Expanded(flex: 2, child: _headerCell('STATUS')),
      Expanded(flex: 2, child: _headerCell('SUBMITTED')),
      Expanded(flex: 2, child: Align(
        alignment: Alignment.centerRight,
        child: _headerCell('ACTIONS'),
      )),
    ]),
  );
}
```

**Issues**:
- **Line 611**: Fixed padding - needs responsive
- **Line 617**: Fixed Row layout - completely unsuitable for mobile
- **Lines 618-626**: 9 columns with flex values - impossible to display on mobile
- **Font size**: 11pt may be too small on mobile

**Changes Required**:
1. Add parameter: `Widget _buildTableHeader(bool isMobile, bool isTablet)`
2. Replace padding: responsive
3. Conditional layout:
   - Mobile: Hide most columns, show only Title and Actions (swipe for more?)
   - Tablet: Show 4-5 key columns
   - Desktop: Show all columns
4. Adjust font size: `isMobile ? 9 : isTablet ? 10 : 11`

---

## 6. TABLE ROW (_buildProposalRow) - Lines 629-721
**Current Structure**:
```dart
Widget _buildProposalRow({
  required String docId,
  required Map<String, dynamic> data,
  required bool isLast,
}) {
  return InkWell(
    hoverColor: const Color(0xFFF8F9FB),
    onTap: () => _openViewModal(docId, data),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),  // LINE 636 - HARDCODED
      decoration: BoxDecoration(...),
      child: Row(children: [  // LINE 640 - Always Row
        Expanded(flex: 4, child: Text(...)),      // LINE 642
        Expanded(flex: 2, child: Container(...)), // LINE 651
        Expanded(flex: 2, child: _audienceChip(...)), // LINE 665
        Expanded(flex: 2, child: Text(...)),      // LINE 669
        Expanded(flex: 2, child: Text(...)),      // LINE 675
        Expanded(flex: 2, child: Text(...)),      // LINE 681
        Expanded(flex: 2, child: _statusBadge(...)), // LINE 687
        Expanded(flex: 2, child: Text(...)),      // LINE 689
        Expanded(flex: 2, child: Row(...)),       // LINE 693 - Actions row
      ]),
    ),
  );
}
```

**Issues**:
- **Line 636**: Fixed padding `symmetric(horizontal: 20, vertical: 14)` - needs responsive
- **Line 640**: Fixed Row layout - must change for mobile
- **All Expanded children**: 9 columns with specific flex ratios - unreadable on mobile
- **Font sizes**: All hardcoded at 12-13pt - too small on mobile
- **Category container**: Line 651 has `horizontal: 8, vertical: 3` padding - needs responsive

**Changes Required**:
1. Add parameters: `Widget _buildProposalRow(..., bool isMobile, bool isTablet)`
2. Replace padding: responsive
3. Conditional layout:
   - Mobile: Vertical Card layout (title, category, status, click to view)
   - Tablet: Reduce columns (title, category, date, status, actions)
   - Desktop: Keep all columns
4. Adjust font sizes: mobile 11pt, tablet 12pt, desktop 13pt
5. Adjust container paddings: responsive
6. Actions button styling: full width on mobile, inline on desktop

---

## 7. TABLE FOOTER - Lines 745-776
**Current Structure**:
```dart
Widget _buildFooter(int total, int totalPages, int start, int end) {
  const int maxVisible = 5;
  // ... pagination logic ...
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),  // LINE 759 - HARDCODED
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
      color: Color(0xFFF8F9FB),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [  // LINE 765 - Row
      Text(
        'Showing ${total == 0 ? 0 : start + 1}–$end of $total proposals',
        style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
      ),
      Row(children: [  // Pagination controls
        _PageButton(...),
        const SizedBox(width: 4),
        ...pages.map((p) => _PageNumButton(...)),
        // More pagination
      ]),
    ]),
  );
}
```

**Issues**:
- **Line 759**: Fixed padding - needs responsive
- **Line 765**: Row layout - may not fit on mobile
- **Font size**: 12pt - needs adjustment
- **Pagination controls**: May wrap awkwardly on mobile
- **Spacing**: `SizedBox(width: 4)` between pagination buttons - fixed

**Changes Required**:
1. Add parameters: `Widget _buildFooter(..., bool isMobile, bool isTablet)`
2. Replace padding: responsive
3. Conditional layout:
   - Mobile: Stack pagination below text (Column instead of Row)
   - Desktop: Keep Row layout
4. Adjust font size: `isMobile ? 10 : 11 : 12`
5. Reduce visible page buttons on mobile (maxVisible = 3 instead of 5)

---

## 8. STAT CARD - Lines 787-829
**Current Structure**:
```dart
class _StatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(18),  // LINE 811 - HARDCODED
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: Row(children: [  // LINE 817 - Row
              Container(
                width: 44, height: 44,  // LINE 818 - FIXED SIZE
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),  // LINE 822 - FIXED ICON SIZE
              ),
              const SizedBox(width: 14),  // LINE 823 - HARDCODED
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, ...)),  // LINE 825
                  const SizedBox(height: 2),
                  Text('$count', style: GoogleFonts.beVietnamPro(fontSize: 28, ...)),  // LINE 827
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
```

**Issues**:
- **Line 811**: Fixed padding `all: 18` - needs responsive
- **Line 818**: Fixed icon container size `44x44` - may be too large on mobile
- **Line 822**: Fixed icon size `22` - needs adjustment
- **Line 823**: Fixed spacing `14` - needs responsive
- **Line 825**: Fixed font size `11` - needs responsive
- **Line 827**: Fixed font size `28` for count - too large on mobile

**Changes Required**:
1. Add parameters to constructor (pass isMobile, isTablet)
2. Replace padding: responsive (12-18 range)
3. Replace icon container size: responsive (36-44 range)
4. Replace icon size: responsive (18-22 range)
5. Replace spacing: responsive (10-14 range)
6. Replace font sizes: responsive

---

## 9. FILTER DROPDOWN - Lines 832-855
**Current Structure**:
```dart
class _FilterDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,  // LINE 842 - FIXED
      padding: const EdgeInsets.symmetric(horizontal: 12),  // LINE 843 - HARDCODED
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      // ...
    );
  }
}
```

**Issues**:
- **Line 842**: Fixed height `40` - may be too tall on mobile
- **Line 843**: Fixed padding `12` - needs responsive

**Changes Required**:
1. Add parameters (isMobile, isTablet)
2. Replace height: responsive (36-40 range)
3. Replace padding: responsive

---

## 10. TOOLBAR BUTTON - Lines 858-887
**Current Structure**:
```dart
class _ToolbarButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        // ...
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),  // LINE 869 - HARDCODED
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      // ...
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),  // LINE 880 - HARDCODED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}
```

**Issues**:
- **Lines 869, 880**: Fixed padding - needs responsive
- Font sizes in button text: Line 866, 877 are 13pt - may need adjustment on mobile

**Changes Required**:
1. Add parameters (isMobile, isTablet)
2. Replace padding: responsive (8-16 range)
3. Adjust font size in labels: responsive

---

## 11. SUBMIT/EDIT MODAL - Lines 920-1556
**Current Structure**:
```dart
class _SubmitProposalModalState extends State<_SubmitProposalModal> {
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editDocId != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),  // LINE 1050
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 560,  // LINE 1052 - FIXED WIDTH
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),  // LINE 1058 - HARDCODED
            // ...
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),  // LINE 1073 - HARDCODED
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionLabel('Event Details', icon: Icons.event_outlined),
                  Row(children: [  // LINE 1078
                    Expanded(
                      child: TextFormField(...),
                    ),
                    const SizedBox(width: 12),  // LINE 1084
                    Expanded(
                      child: DropdownButtonFormField<String>(...),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(...),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLines: 3,
                    // ...
                  ),
                  const SizedBox(height: 12),
                  Row(children: [  // LINE 1111 - 3 time fields in Row
                    Expanded(child: TextFormField(...)),
                    const SizedBox(width: 12),  // LINE 1123
                    Expanded(child: TextFormField(...)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(...)),
                  ]),
                  // ... more fields ...
                ]),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),  // LINE 1542
            // ...
          ),
        ]),
      ),
    );
  }
}
```

**Issues**:
- **Line 1050**: Fixed inset padding - needs responsive
- **Line 1052**: Fixed width `560` - too wide on mobile (should be ~90% of screen)
- **Line 1058**: Fixed header padding - needs responsive
- **Line 1073**: Fixed content padding - needs responsive
- **Lines 1078, 1111**: Row layouts with fields - should stack on mobile
- **Lines 1084, 1123**: Fixed spacing - needs responsive
- **Line 1542**: Fixed footer padding - needs responsive
- All TextFormFields need responsive styling
- Font sizes in various input decorations need adjustment

**Changes Required**:
1. Replace inset padding: responsive (16-32 range)
2. Replace width: responsive (min(90%, 560) or similar logic)
3. Replace padding: responsive in header, content, footer
4. Conditional Row/Column for form fields:
   - Mobile: Column layout (single column)
   - Tablet: 2-column layout for some groups
   - Desktop: 2-3 column layout as current
5. Adjust all internal spacing based on screen size
6. Adjust font sizes for inputs and labels
7. Possibly wrap in SingleChildScrollView for mobile

---

## 12. VIEW MODAL - Lines 1609-1765
**Current Structure**:
```dart
class _ViewProposalModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 520,  // LINE 1675 - FIXED WIDTH
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),  // LINE 1679 - HARDCODED
            decoration: BoxDecoration(...),
            child: Row(children: [  // LINE 1685
              Container(
                width: 38, height: 38,  // LINE 1686 - FIXED SIZE
                // ...
              ),
              const SizedBox(width: 14),  // LINE 1691 - HARDCODED
              // ... Title section ...
              _statusBadge(status),
              const SizedBox(width: 8),  // LINE 1698 - HARDCODED
              IconButton(...),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),  // LINE 1703 - HARDCODED
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [  // LINE 1705
                  Expanded(child: _detailItem(...)),
                  const SizedBox(width: 16),  // LINE 1707 - HARDCODED
                  Expanded(child: _detailItem(...)),
                ]),
                const SizedBox(height: 14),  // LINE 1709 - HARDCODED
                _detailItem(...),
                const SizedBox(height: 14),
                Row(children: [  // LINE 1712
                  Expanded(child: _detailItem(...)),
                  const SizedBox(width: 16),
                  Expanded(child: _detailItem(...)),
                ]),
                // ... more detail items ...
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),  // LINE 1748 - HARDCODED
            // ...
          ),
        ]),
      ),
    );
  }
}
```

**Issues**:
- **Line 1675**: Fixed width `520` - too wide on mobile
- **Line 1679**: Fixed header padding - needs responsive
- **Line 1686**: Fixed icon size - needs responsive
- **Line 1691, 1698**: Fixed spacing - needs responsive
- **Line 1703**: Fixed content padding - needs responsive
- **Lines 1705, 1712**: Row layouts - should stack on mobile
- **Line 1707, 1709, 1716, etc.**: Fixed vertical/horizontal spacing - needs responsive
- **Line 1748**: Fixed footer padding - needs responsive

**Changes Required**:
1. Replace width: responsive calculation
2. Replace padding: responsive throughout
3. Replace all SizedBox spacings: responsive
4. Replace icon sizes: responsive
5. Conditional Row/Column layouts for detail display
6. Adjust font sizes in _detailItem and elsewhere

---

## 13. HELPER METHODS - Miscellaneous

### _audienceChip (Lines 723-740)
- **Line 728**: Fixed padding `symmetric(horizontal: 8, vertical: 3)` - responsive
- **Font size**: 11pt - needs adjustment

### _buildEmptyState (Lines 742-759)
- **Line 745**: Fixed container size `80x80` - responsive
- **Line 747**: Fixed border radius `20` - responsive
- **Line 749**: Fixed icon size `40` - responsive
- **Lines 751, 754**: Fixed SizedBox spacing - responsive
- **Font sizes**: 15pt, 13pt - needs responsive

### _PageButton, _PageNumButton (Lines 892-930)
- **Line 901**: Padding `all: 4` - needs responsive
- **Line 909**: Container size `28x28` - needs responsive
- **Font size**: 12pt - needs responsive

### _headerCell (Lines 628-635)
- **Font size**: 11pt - needs responsive
- **Letter spacing**: 0.7 - may need adjustment

### Padding throughout
Many small paddings and margins using fixed values (2, 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 28)

---

## Summary of Changes Required

### Critical Changes:
1. **Screen Size Detection** - Add at build() method start
2. **Primary Paddings** - All EdgeInsets.fromLTRB values (28, 20, 24 → responsive)
3. **Layout Direction** - All Row widgets should conditionally become Column on mobile
4. **Table Redesign** - Complete rework for mobile (card-based layout)
5. **Modal Sizing** - Width and padding adjustments
6. **Typography** - All font sizes need responsive variants

### High Priority:
- _buildStatsRow(): padding + layout
- _buildToolbar(): padding + layout + button sizing
- _buildTable(): margin + complete redesign
- _buildTableHeader(): complete redesign for mobile
- _buildProposalRow(): complete redesign for mobile
- Submit/Edit Modal: width + padding + layout
- View Modal: width + padding + layout

### Medium Priority:
- _buildFooter(): pagination layout
- All spacing between components (SizedBox widths/heights)
- Icon sizes and container sizes
- _StatCard styling
- Filter and button styling

### Low Priority:
- Letter spacing adjustments
- Minor color/styling refinements
- Optional: Animation adjustments for responsive behavior

---

## Responsive Breakpoints Pattern (from org_certificates.dart)

```dart
// In build() method:
final screenWidth = MediaQuery.of(context).size.width;
final isMobile = screenWidth < 768;
final isTablet = screenWidth < 1200;

// Then pass to helper methods:
_buildStatsRow(isMobile, isTablet),
_buildToolbar(isMobile, isTablet),
```

---

## Implementation Strategy

1. **Phase 1**: Add screen size detection to build() method
2. **Phase 2**: Update all method signatures to accept isMobile, isTablet
3. **Phase 3**: Update padding/margin values with responsive calculation
4. **Phase 4**: Convert Row/Column layouts conditionally
5. **Phase 5**: Update typography (font sizes)
6. **Phase 6**: Redesign tables and modals for mobile
7. **Phase 7**: Test and fine-tune spacing

---

## Total Estimated Changes
- **Methods to Modify**: 15+
- **Padding Values to Update**: 30+
- **Layout Conditionals to Add**: 8+
- **Font Sizes to Update**: 20+
- **SizedBox Spacings to Update**: 40+
