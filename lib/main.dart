import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const WheelchairBasketApp());
}

class WheelchairBasketApp extends StatelessWidget {
  const WheelchairBasketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '車椅子バスケ マネージャー',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TeamMakerScreen(),
    );
  }
}

// 選手データクラス
class Player {
  final String id;
  final String name;
  final double points;
  Player({required this.id, required this.name, required this.points});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'points': points};
  factory Player.fromJson(Map<String, dynamic> json) =>
      Player(id: json['id'], name: json['name'], points: json['points']);
}

class TeamMakerScreen extends StatefulWidget {
  const TeamMakerScreen({super.key});
  @override
  State<TeamMakerScreen> createState() => _TeamMakerScreenState();
}

class _TeamMakerScreenState extends State<TeamMakerScreen> {
  List<Player> allMasterPlayers = []; // マスター登録されている全選手
  Set<String> participatingIds = {};   // 「参加」にチェックが入っている選手のID
  
  List<Player> whiteCourt = [];
  List<Player> whiteBench = [];
  List<Player> blackCourt = [];
  List<Player> blackBench = [];

  @override
  void initState() {
    super.initState();
    _loadData(); // 起動時にデータを読み込む
  }

  // データの保存
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('master_players', json.encode(allMasterPlayers.map((p) => p.toJson()).toList()));
    await prefs.setString('participating_ids', json.encode(participatingIds.toList()));
  }

  // データの読み込み
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? masterData = prefs.getString('master_players');
    final String? partData = prefs.getString('participating_ids');
    setState(() {
      if (masterData != null) {
        allMasterPlayers = (json.decode(masterData) as List).map((p) => Player.fromJson(p)).toList();
      }
      if (partData != null) {
        participatingIds = Set<String>.from(json.decode(partData));
      }
    });
  }

  // 現在「参加者」エリアに表示すべき選手のリスト
  List<Player> get currentParticipants {
    final assignedIds = [...whiteCourt, ...whiteBench, ...blackCourt, ...blackBench].map((p) => p.id).toSet();
    return allMasterPlayers
        .where((p) => participatingIds.contains(p.id) && !assignedIds.contains(p.id))
        .toList()
      ..sort((a, b) => a.points.compareTo(b.points));
  }

  // ドラッグ＆ドロップ時の移動処理
  void movePlayer(Player player, String targetZone) {
    setState(() {
      // 全てのリストから一旦削除
      [whiteCourt, whiteBench, blackCourt, blackBench].forEach((list) => list.removeWhere((p) => p.id == player.id));

      // 指定されたゾーンに追加
      if (targetZone == 'w_c') whiteCourt.add(player);
      if (targetZone == 'w_b') whiteBench.add(player);
      if (targetZone == 'b_c') blackCourt.add(player);
      if (targetZone == 'b_b') blackBench.add(player);

      // 各リストを点数順にソート
      [whiteCourt, whiteBench, blackCourt, blackBench].forEach((list) => list.sort((a, b) => a.points.compareTo(b.points)));
    });
  }

  double calcSum(List<Player> list) => list.fold(0, (s, p) => s + p.points);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // --- 左 1/3: 参加者 (中央寄せ表示) ---
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        border: const Border(right: BorderSide(color: Colors.grey, width: 2)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.blue[200],
                            child: const Text("参加者", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: DragTarget<Player>(
                              onAccept: (p) => setState(() {
                                // チームから参加者リストに戻す処理
                                [whiteCourt, whiteBench, blackCourt, blackBench].forEach((list) => list.removeWhere((x) => x.id == p.id));
                              }),
                              builder: (context, _, __) => Center(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: currentParticipants.length,
                                  itemBuilder: (context, index) => _PlayerTile(
                                    player: currentParticipants[index], 
                                    textColor: Colors.black, 
                                    verticalPadding: 10.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // --- 右 2/3: 白・黒チーム (5:5分割) ---
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(flex: 1, child: _buildTeamSection("白", whiteCourt, whiteBench, Colors.white, Colors.black, 'w_c', 'w_b')),
                        const Divider(height: 1, thickness: 1, color: Colors.grey),
                        Expanded(flex: 1, child: _buildTeamSection("黒", blackCourt, blackBench, Colors.black, Colors.white, 'b_c', 'b_b')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 管理ボタン
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _navigateToManage(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Text("選手マスター登録・参加選択"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection(String label, List<Player> court, List<Player> bench, Color bg, Color txt, String cKey, String bKey) {
    return Container(
      color: bg,
      child: Column(
        children: [
          _buildZone("$label コート内 (計: ${calcSum(court).toStringAsFixed(1)})", court, bg, txt, cKey, showTitle: true, flex: 3),
          const Divider(height: 1, color: Colors.grey),
          _buildZone("", bench, bg, txt, bKey, showTitle: false, flex: 2),
        ],
      ),
    );
  }

  Widget _buildZone(String title, List<Player> players, Color bg, Color txt, String key, {bool showTitle = true, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: DragTarget<Player>(
        onAccept: (p) => movePlayer(p, key),
        builder: (context, _, __) => Container(
          decoration: BoxDecoration(color: bg),
          child: Column(
            children: [
              if (showTitle)
                Container(
                  width: double.infinity,
                  color: txt.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: txt, fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: players.length,
                  itemBuilder: (context, index) => _PlayerTile(player: players[index], textColor: txt, verticalPadding: 4.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToManage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ManagePlayersScreen(
        allPlayers: allMasterPlayers,
        initialParticipatingIds: participatingIds,
      )),
    );

    if (result != null) {
      setState(() {
        allMasterPlayers = result['all'];
        participatingIds = result['participating'];
        // もし「参加」から外された人がコートにいたら消す
        [whiteCourt, whiteBench, blackCourt, blackBench].forEach((list) {
          list.removeWhere((p) => !participatingIds.contains(p.id));
        });
      });
      _saveData();
    }
  }
}

// 選手タイルの部品
class _PlayerTile extends StatelessWidget {
  final Player player;
  final Color textColor;
  final double verticalPadding;
  const _PlayerTile({required this.player, required this.textColor, required this.verticalPadding});

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Player>(
      delay: const Duration(milliseconds: 100),
      data: player,
      feedback: Material(
        elevation: 6,
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.orange,
          child: Text(player.name, style: const TextStyle(color: Colors.white, fontSize: 18, decoration: TextDecoration.none)),
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(player.name, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w900))),
            Text(player.points.toStringAsFixed(1), style: TextStyle(color: textColor, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// 選手管理画面
class ManagePlayersScreen extends StatefulWidget {
  final List<Player> allPlayers;
  final Set<String> initialParticipatingIds;
  const ManagePlayersScreen({super.key, required this.allPlayers, required this.initialParticipatingIds});

  @override
  State<ManagePlayersScreen> createState() => _ManagePlayersScreenState();
}

class _ManagePlayersScreenState extends State<ManagePlayersScreen> {
  late List<Player> tempAll;
  late Set<String> tempParticipating;
  final nameCtrl = TextEditingController();
  double selectedPoints = 1.0;

  @override
  void initState() {
    super.initState();
    tempAll = List.from(widget.allPlayers);
    tempParticipating = Set.from(widget.initialParticipatingIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("選手マスター管理"),
        leading: IconButton(
          icon: const Icon(Icons.check), // 確定して戻る
          onPressed: () => Navigator.pop(context, {'all': tempAll, 'participating': tempParticipating}),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "選手名"))),
                DropdownButton<double>(
                  value: selectedPoints,
                  items: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                  onChanged: (v) => setState(() => selectedPoints = v!),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    setState(() {
                      final newPlayer = Player(id: DateTime.now().toString(), name: nameCtrl.text, points: selectedPoints);
                      tempAll.add(newPlayer);
                      tempParticipating.add(newPlayer.id); // 追加したらデフォルトで参加
                      nameCtrl.clear();
                    });
                  }
                }, child: const Text("登録")),
              ],
            ),
          ),
          const Divider(),
          const Text("選手一覧（チェックで参加）", style: TextStyle(color: Colors.grey)),
          Expanded(
            child: ListView.builder(
              itemCount: tempAll.length,
              itemBuilder: (context, index) {
                final player = tempAll[index];
                return CheckboxListTile(
                  title: Text("${player.name} (${player.points})"),
                  value: tempParticipating.contains(player.id),
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) tempParticipating.add(player.id);
                      else tempParticipating.remove(player.id);
                    });
                  },
                  secondary: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() {
                      tempParticipating.remove(player.id);
                      tempAll.removeAt(index);
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}