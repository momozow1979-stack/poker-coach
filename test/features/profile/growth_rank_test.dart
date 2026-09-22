import 'package:ai_poker_coach/features/profile/application/progress_providers.dart';
import 'package:ai_poker_coach/features/profile/domain/growth_rank.dart';
import 'package:ai_poker_coach/features/quiz/domain/learning_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GrowthRank.forProgress（座学＋レンジ暗記で昇格）', () {
    GrowthRank rank(int solved, {bool open = false, bool vsOpen = false}) =>
        GrowthRank.forProgress(
          uniqueSolved: solved,
          openDrillCleared: open,
          vsOpenDrillCleared: vsOpen,
        );

    test('座学の到達数で見習い→一人前まで上がる', () {
      expect(rank(0), GrowthRank.apprentice);
      expect(rank(29), GrowthRank.apprentice);
      expect(rank(30), GrowthRank.training);
      expect(rank(100), GrowthRank.journeyman);
    });

    test('熟練以上はレンジ暗記のクリアが要る', () {
      // 250問あってもオープン未クリアなら一人前どまり。
      expect(rank(250), GrowthRank.journeyman);
      expect(rank(250, open: true), GrowthRank.skilled);
      // 450問でも vsオープン未クリアなら熟練どまり。
      expect(rank(450, open: true), GrowthRank.skilled);
      expect(rank(450, open: true, vsOpen: true), GrowthRank.expert);
    });

    test('名人は 700問＋両方クリア', () {
      expect(rank(700, open: true), GrowthRank.skilled);
      expect(rank(700, open: true, vsOpen: true), GrowthRank.master);
    });

    test('Lv 番号は 1〜6', () {
      expect(GrowthRank.apprentice.level, 1);
      expect(GrowthRank.master.level, 6);
    });
  });

  group('StageProgress（問題数の進捗 × 正解率）', () {
    test('進捗＝こなした問題/総問題、正解率＝正解/こなした', () {
      const p = StageProgress(
        stage: LearningStage.preflop,
        attempted: 5,
        solved: 4,
        total: 10,
      );
      expect(p.progress, closeTo(0.5, 1e-9));
      expect(p.accuracy, closeTo(0.8, 1e-9));
      expect(p.cleared, isFalse);
    });

    test('全問を正解済みで Clear（進捗×正解率＝100%）', () {
      const p = StageProgress(
        stage: LearningStage.preflop,
        attempted: 10,
        solved: 10,
        total: 10,
      );
      expect(p.progress, 1.0);
      expect(p.accuracy, 1.0);
      expect(p.cleared, isTrue);
    });

    test('未着手は進捗0・未クリア', () {
      const p = StageProgress(
        stage: LearningStage.preflop,
        attempted: 0,
        solved: 0,
        total: 10,
      );
      expect(p.progress, 0.0);
      expect(p.cleared, isFalse);
    });
  });
}
