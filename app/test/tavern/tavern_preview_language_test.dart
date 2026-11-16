import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/tavern/tavern_preview.dart';
import 'package:dsh_tavern/dsh_tavern.dart';
import 'package:flutter_test/flutter_test.dart';

final _han = RegExp(r'[\u3400-\u9fff]');

void main() {
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  test('the sample cards are Chinese by default and English for an English app', () async {
    var tavern = PreviewTavern(tick: Duration.zero);
    var cards = await tavern.watchCharacters().first;
    expect(cards.first.name, '林晚');
    expect(cards.first.tags, contains('示例'));

    AppLocale.use(AppLocale.en);
    tavern = PreviewTavern(tick: Duration.zero);
    cards = await tavern.watchCharacters().first;
    expect(cards.first.name, 'Mira');
    expect(cards.first.tags, contains('Sample'));
    expect(cards[1].name, 'Star Chart');
    for (final card in cards) {
      expect(card.description, isNot(matches(_han)));
      expect(card.creatorNotes, isNot(matches(_han)));
    }
  });

  test('the preview replies in the app language', () async {
    AppLocale.use(AppLocale.en);
    final tavern = PreviewTavern(tick: Duration.zero);
    final chat = await tavern.createChat('sample-innkeeper');
    final done = await tavern
        .send(chat, 'Who is down there?')
        .where((event) => event is TavernTurnDone)
        .cast<TavernTurnDone>()
        .first;
    expect(done.message.text, contains('That question'));
    expect(done.message.text, isNot(matches(_han)));
  });
}
