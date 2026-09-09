from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text()

# The calculator and the app use pt_BR DateFormat/NumberFormat.
# Keep exactly one locale-data import and one initialization call.
locale_import = "import 'package:intl/date_symbol_data_local.dart';"
intl_import = "import 'package:intl/intl.dart';"
locale_init = "  await initializeDateFormatting('pt_BR', null);"

# Remove duplicates first, preserving a single canonical occurrence.
s = re.sub(
    r"(?:import 'package:intl/date_symbol_data_local\.dart';\r?\n)+",
    locale_import + "\n",
    s,
    count=1,
)
if locale_import not in s:
    s = s.replace(intl_import, locale_import + "\n" + intl_import, 1)

s = re.sub(
    r"(?:  await initializeDateFormatting\('pt_BR', null\);\r?\n)+",
    locale_init + "\n",
    s,
    count=1,
)
if locale_init not in s:
    s = s.replace("  await initSupabase();", locale_init + "\n  await initSupabase();", 1)

old_theme = """      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito',
        colorSchemeSeed: const Color(0xFF7C3AED),
      ),"""
new_theme = """      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFF0A0618),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          onPrimary: Colors.white,
          secondary: Color(0xFFEC4899),
          onSecondary: Colors.white,
          tertiary: Color(0xFFEF4444),
          onTertiary: Colors.white,
          surface: Color(0xFF120A2B),
          onSurface: Color(0xFFF8F5FF),
          error: Color(0xFFFF5252),
          onError: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF17102F),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),"""
s = s.replace(old_theme, new_theme, 1)

old_appbar = """      appBar: AppBar(title:const Text('Roots Cobrança',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(tooltip:'Sair',onPressed:()=>CobrAppRepository().db.auth.signOut(),icon:const Icon(Icons.logout))]),"""
new_appbar = """      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFBE185D), Color(0xFFEF233C)],
            ),
          ),
        ),
        title: Row(children:[
          Container(width:38,height:38,decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),gradient:const LinearGradient(colors:[Color(0xFFA855F7),Color(0xFFEC4899)])),child:const Icon(Icons.account_balance_wallet_rounded,color:Colors.white,size:22)),
          const SizedBox(width:11),
          const Text('Roots Cobrança',style:TextStyle(fontWeight:FontWeight.w900,fontSize:21)),
        ]),
        actions:[IconButton(tooltip:'Sair',onPressed:()=>CobrAppRepository().db.auth.signOut(),icon:const Icon(Icons.logout_rounded))],
      ),"""
s = s.replace(old_appbar, new_appbar, 1)

old_nav = """      bottomNavigationBar:NavigationBar(selectedIndex:tab>4?0:tab,onDestinationSelected:(index)=>setState(()=>tab=index),indicatorColor:cs.primaryContainer,destinations:const ["""
new_nav = """      bottomNavigationBar:NavigationBar(
        selectedIndex:tab>4?0:tab,
        onDestinationSelected:(index)=>setState(()=>tab=index),
        backgroundColor:const Color(0xFF120A2B),
        elevation:12,
        indicatorColor:const Color(0xFF9D174D),
        labelTextStyle:const WidgetStatePropertyAll(TextStyle(fontWeight:FontWeight.w700)),
        destinations:const ["""
s = s.replace(old_nav, new_nav, 1)

pattern = r"""            SliverAppBar\(\n              pinned: true,\n              title: const Text\('Roots Cobrança', style: TextStyle\(fontWeight: FontWeight\.w800\)\),\n              actions: \[\n                IconButton\(\n                  tooltip: 'Sair',\n                  onPressed: \(\) => CobrAppRepository\(\)\.db\.auth\.signOut\(\),\n                  icon: const Icon\(Icons\.logout\),\n                \),\n              \],\n            \),\n"""
s = re.sub(pattern, '', s, count=1)

s = s.replace("return CustomScrollView(\n          slivers: [", "return Container(\n          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors: [Color(0xFF160A31), Color(0xFF0A0618)])),\n          child: CustomScrollView(\n          slivers: [", 1)
s = s.replace("            SliverPadding(\n              padding: const EdgeInsets.all(16),", "            SliverPadding(\n              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),", 1)
s = s.replace("Text('Resumo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),", "Text('Resumo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),\n                  const SizedBox(height: 7),\n                  Container(width:125,height:5,decoration:BoxDecoration(borderRadius:BorderRadius.circular(99),gradient:const LinearGradient(colors:[Color(0xFFEC4899),Color(0xFF8B5CF6)]))),", 1)
s = s.replace("Card(\n                    child: Padding(\n                      padding: const EdgeInsets.all(18),", "Card(clipBehavior: Clip.antiAlias, color: const Color(0xFF21113F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF7C3AED))),\n                    child: Padding(\n                      padding: const EdgeInsets.all(20),", 1)
s = s.replace("const Text('Migração Supabase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),", "const Row(children:[Icon(Icons.cloud_done_rounded,color:Color(0xFF22C55E)),SizedBox(width:10),Text('Migração Supabase', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))]),", 1)
s = s.replace("    return Card(\n      child: Padding(\n        padding: const EdgeInsets.all(14),", "    return Card(clipBehavior: Clip.antiAlias, color: const Color(0xFF17102F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFF3B1F6B))),\n      child: Padding(\n        padding: const EdgeInsets.all(16),", 1)
s = s.replace("CircleAvatar(child: Icon(icon, size: 20)),", "CircleAvatar(backgroundColor: const Color(0xFF5B21B6), child: Icon(icon, size: 20, color: Colors.white)),", 1)

s = s.replace("          ],\n        );\n      },\n    );\n  }\n}\n\nclass ReportsPage", "          ],\n        ),\n        );\n      },\n    );\n  }\n}\n\nclass ReportsPage", 1)

# Remove the now-unused color scheme local from HomePage, even if indentation changes.
s = re.sub(r"^[ \t]*final cs = Theme\.of\(context\)\.colorScheme;\r?\n", "", s, count=1, flags=re.MULTILINE)

p.write_text(s)

cpath = Path('lib/calculator_page.dart')
c = cpath.read_text()
c = c.replace("        Card(\n          child: Padding(\n            padding: const EdgeInsets.all(16),", "        Card(\n          elevation: 0,\n          color: const Color(0xFFF4EEFF),\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE1D2FF))),\n          child: Padding(\n            padding: const EdgeInsets.all(18),", 1)
cpath.write_text(c)

# Idempotent visual patch.
