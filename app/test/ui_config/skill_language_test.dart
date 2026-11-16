// Bilingual bundled skills: every skill ship both instruction languages,
// manifest.json maps an `en` variant of SKILL.md, and provisioning installs
// the one that matches the app language without touching a folder the person
// took over.

import 'dart:io';

import 'package:dsh_app/ui_config/ui_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const skills = [
  uiSkillName,
  pluginSkillName,
  guideSkillName,
  supportSkillName,
  companionAdaptSkillName,
  petThemeSkillName,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final name in skills) {
    test('$name: Chinese default, English variant, same front matter name', () async {
      final zh = await loadUiSkillBundle(readAssetFromDisk, name);
      final en = await loadUiSkillBundle(readAssetFromDisk, name, null, 'en');
      expect(en.name, name);
      expect(en.files.keys.toSet(), zh.files.keys.toSet(), reason: 'the same installed paths');
      expect(en.skillMd, isNot(zh.skillMd), reason: 'English is a real translation, not a copy');
      expect(en.skillMd.split('\n').first, '---');
      expect(en.skillMd, contains('# dsh-go:managed'));
      expect(en.skillMd, contains('name: $name\n'));
      // The Chinese source is kept: both variants ship in the bundle.
      final assets = Directory('$appDir/assets/skills/$name');
      final flat = name == pluginSkillName || name == guideSkillName ? 'en-SKILL.md' : 'SKILL.en.md';
      expect(File('${assets.path}/$flat').existsSync(), isTrue, reason: flat);
    });
  }

  test('guide: Chinese and English pages are both installed', () async {
    final zh = await loadUiSkillBundle(readAssetFromDisk, guideSkillName);
    final en = await loadUiSkillBundle(readAssetFromDisk, guideSkillName, null, 'en');
    expect(en.files.keys, containsAll(['zh/01-chat.md', 'en/01-chat.md']));
    expect(en.skillMd, contains('The pages are in this skill folder'));
    expect(zh.skillMd, contains('说明文件都在本技能目录里'));
  });

  test('guide: HarmonyOS English instructions replace the shared English SKILL.md only there', () async {
    final android = await loadUiSkillBundle(readAssetFromDisk, guideSkillName, null, 'en');
    final harmony = await loadUiSkillBundle(readAssetFromDisk, guideSkillName, 'ohos', 'en');
    expect(android.skillMd, contains('Platform check'));
    expect(harmony.skillMd, contains('(HarmonyOS)'));
    expect(harmony.files.keys.toSet(), android.files.keys.toSet());
    expect(harmony.files.keys, containsAll(['zh/01-chat.md', 'en/01-chat.md']));
    final harmonyZh = await loadUiSkillBundle(readAssetFromDisk, guideSkillName, 'ohos');
    expect(harmonyZh.skillMd, contains('鸿蒙版'));
  });

  test('a skill without an English variant keeps the Chinese default', () async {
    final zh = await loadUiSkillBundle(readAssetFromDisk, guideSkillName);
    final missing = await loadUiSkillBundle((key) async {
      if (key.endsWith('manifest.json')) {
        return '{"name":"dsh-go-guide","files":{"SKILL.md":"SKILL.md"}}';
      }
      return zh.files['SKILL.md']!;
    }, guideSkillName, null, 'en');
    expect(missing.name, guideSkillName);
    expect(missing.files.keys, ['SKILL.md']);
  });

  test('companion-adapt: the English skill installs the English contract at the same path', () async {
    final zh = await loadUiSkillBundle(readAssetFromDisk, companionAdaptSkillName);
    final en = await loadUiSkillBundle(readAssetFromDisk, companionAdaptSkillName, null, 'en');
    expect(zh.files['references/contract.txt'], contains('你在帮 dsh-go'));
    expect(en.files['references/contract.txt'], contains('You are helping the dsh-go companion app'));
    expect(en.skillMd, contains('references/contract.txt'));
    expect(en.files.keys, zh.files.keys.toSet());

    final root = tempRootfs();
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    expect(await installUiSkill(root, en), UiSkillInstallResult.installed);
    final installed = File('${root.path}/root/.dsh/skills/$companionAdaptSkillName/references/contract.txt');
    expect(installed.readAsStringSync(), en.files['references/contract.txt']);
  });

  test('switching language installs the English SKILL.md and keeps the rest', () async {
    final root = tempRootfs();
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final zh = await loadUiSkillBundle(readAssetFromDisk, petThemeSkillName);
    final en = await loadUiSkillBundle(readAssetFromDisk, petThemeSkillName, null, 'en');
    expect(await installUiSkill(root, zh), UiSkillInstallResult.installed);
    expect(await installUiSkill(root, en), UiSkillInstallResult.updated);
    final dir = Directory('${root.path}/root/.dsh/skills/$petThemeSkillName');
    expect(File('${dir.path}/SKILL.md').readAsStringSync(), en.skillMd);
    for (final path in en.files.keys.where((p) => p != 'SKILL.md')) {
      expect(File('${dir.path}/$path').readAsStringSync(), en.files[path], reason: path);
    }
  });

  test('a folder the person took over survives a language switch', () async {
    final root = tempRootfs();
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final dir = Directory('${root.path}/root/.dsh/skills/$petThemeSkillName');
    dir.createSync(recursive: true);
    File('${dir.path}/SKILL.md').writeAsStringSync('---\nname: pet-theme\n---\nmine\n');
    final en = await loadUiSkillBundle(readAssetFromDisk, petThemeSkillName, null, 'en');
    expect(await installUiSkill(root, en), UiSkillInstallResult.userOwned);
    expect(File('${dir.path}/SKILL.md').readAsStringSync(), endsWith('mine\n'));
  });
}
