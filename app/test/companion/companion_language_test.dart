// Her prompt text follows the app language: Chinese stays the default and is
// never rewritten; English is chosen only while the app is showing English.
import 'package:dsh_app/companion/companion_adapt_contract.dart';
import 'package:dsh_app/companion/companion_context.dart';
import 'package:dsh_app/companion/companion_moves.dart';
import 'package:dsh_app/companion/companion_reply.dart';
import 'package:dsh_app/companion/companion_state.dart';
import 'package:dsh_app/companion/companion_voice_source.dart';
import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

CompanionMemory _memory(String text) => CompanionMemory(id: 'm1', text: text);

void main() {
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  test('voice provider labels follow live language changes without changing ids', () {
    final mimo = companionVoicePresets.firstWhere((preset) => preset.id == 'mimo');
    final silicon = companionVoicePresets.firstWhere((preset) => preset.id == 'siliconflow');
    final bailian = companionVoicePresets.firstWhere((preset) => preset.id == 'bailian');
    expect(mimo.name, '小米 MiMo');
    AppLocale.use(AppLocale.en);
    expect(mimo.name, 'Xiaomi MiMo');
    expect(silicon.name, 'SiliconFlow');
    expect(bailian.name, 'Alibaba Cloud Model Studio');
    AppLocale.use(AppLocale.zhCN);
    expect(mimo.name, '小米 MiMo');
    expect(silicon.name, '硅基流动');
  });

  test('Chinese remains the default prompt language', () {
    AppLocale.use(AppLocale.zhCN);
    expect(companionPersona(), companionPersonaCore);
    expect(companionPersonaCore, startsWith('你是鲸鱼娘，'));
    expect(companionPersonaCore, contains('[表情:开心]'));
    expect(companionAside(now: DateTime(2026, 11, 6, 9, 5)), '〔11月6日 周五 09:05〕');
  });

  test('English selects an English default persona, rules and no-tools line', () {
    AppLocale.use(AppLocale.en);
    final persona = companionPersona();
    expect(persona, startsWith('You are Whale Girl,'));
    expect(persona, isNot(contains('你是鲸鱼娘')));
    expect(persona, contains('[emotion:happy]'));
    expect(persona, contains('[action:nod]'));
    expect(persona, contains('You have no tools right now'));
  });

  test('a user-authored persona is preserved verbatim in either language', () {
    AppLocale.use(AppLocale.en);
    final persona = companionPersona(custom: '你是一只猫娘。', name: '小蓝', callMe: '阿周');
    expect(persona, startsWith('Your name is "小蓝".\n你是一只猫娘。'));
    expect(persona, contains('Call the person "阿周".'));
    expect(persona, contains('你是一只猫娘。'), reason: 'the person wrote this');
    expect(companionPersonaUpdate(custom: '你是一只猫娘。'), contains('The person changed your settings'));
    expect(companionNameNote('小蓝'), contains('"小蓝"'));
  });

  test('English replies parse English marks and date asides', () {
    final reply = parseCompanionReply('[emotion:happy]Hello.[action:wave]');
    expect(reply.words, 'Hello.');
    expect(reply.marks.map((m) => m.name), ['happy', 'wave']);
    final aside = companionAside(
      now: DateTime(2026, 11, 6, 9, 5),
      notes: const ['The person just patted your head.'],
      language: 'en',
    );
    expect(aside, startsWith('〔Nov 6 Fri 09:05, '));
    expect(companionSaidText('$aside\nAre you there?'), 'Are you there?');
    // A Chinese aside written before the switch still reads as the app's line.
    expect(companionSaidText('〔11月6日 周五 09:05〕\n在吗'), '在吗');
  });

  test('model moves are introduced in the prompt language', () {
    const moves = CompanionMoves(
      expressions: [CompanionMove(kind: CompanionMoveKind.expression, raw: 'smile', label: 'smile', ai: true)],
      motions: [CompanionMove(kind: CompanionMoveKind.motion, raw: 'TapBody', label: 'tap', ai: true)],
    );
    expect(moves.rules(language: 'en'), contains('- Expression: [emotion:smile]'));
    expect(moves.rules(language: 'en'), contains('- Action: [action:tap]'));
    expect(moves.rules(language: 'zh'), contains('- 表情：[表情:smile]'));
    expect(moves.rules(language: 'en'), isNot(contains('这个角色')));
  });

  test('light-mode memory intro follows the language, memory text does not', () {
    final system = companionLightSystem([_memory('喜欢下雨天')], language: 'en');
    expect(system, startsWith('You are Whale Girl,'));
    expect(system, contains('Things the person confirmed and asked you to remember'));
    expect(system, contains('- 喜欢下雨天'));
    expect(system, isNot(contains('对方确认过')));
  });

  test('the full-mode profile carries the language to the host', () {
    const profile = CompanionContextProfile(persona: '', language: 'en');
    expect(profile.toJson()['language'], 'en');
    expect(const CompanionContextProfile().toJson()['language'], 'zh');
    // An older host rejects a profile field it does not know: omit it there.
    const old = CompanionContextProfile(persona: '', language: 'en', includeLanguage: false);
    expect(old.toJson().containsKey('language'), isFalse);
  });

  test('the adaptation contract has a separate English vocabulary and prompt', () {
    expect(companionAdaptSystemFor('en'), isNot(companionAdaptSystem));
    expect(companionAdaptSystemFor('en'), contains('You are helping the dsh-go companion app'));
    expect(companionAdaptSystemFor('zh'), companionAdaptSystem);
    expect(companionAdaptParamsFor('en')['ParamAngleX'], contains('Head turn'));
    expect(companionAdaptParamsFor('zh')['ParamAngleX'], contains('头左右转'));
  });

  test('the default voice style follows the app language', () {
    AppLocale.use(AppLocale.en);
    expect(companionVoiceStyleDefault, contains('natural, gentle'));
    AppLocale.use(AppLocale.zhCN);
    expect(companionVoiceStyleDefault, companionVoiceStyleDefaultZh);
  });
}
