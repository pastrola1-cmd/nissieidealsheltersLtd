import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nissie_ideal_shelters/models/models.dart';
import 'package:nissie_ideal_shelters/services/supabase_service.dart';

class TrainingService {
  final SupabaseService _supabaseService;

  TrainingService(this._supabaseService);

  // ── Database Methods ──

  Future<List<TrainingMaterial>> getMaterials(String companyId) async {
    final response = await _supabaseService.client
        .from('training_materials')
        .select()
        .eq('company_id', companyId);
    return (response as List).map((x) => TrainingMaterial.fromJson(x)).toList();
  }

  Future<TrainingMaterial> createMaterial(Map<String, dynamic> data) async {
    final response = await _supabaseService.client
        .from('training_materials')
        .insert(data)
        .select()
        .single();
    return TrainingMaterial.fromJson(response);
  }

  Future<void> deleteMaterial(String id) async {
    await _supabaseService.client.from('training_materials').delete().eq('id', id);
  }

  Future<List<TrainingSimulator>> getSimulators(String companyId) async {
    final response = await _supabaseService.client
        .from('training_simulators')
        .select()
        .eq('company_id', companyId);
    return (response as List).map((x) => TrainingSimulator.fromJson(x)).toList();
  }

  Future<TrainingSimulator> createSimulator(Map<String, dynamic> data) async {
    final response = await _supabaseService.client
        .from('training_simulators')
        .insert(data)
        .select()
        .single();
    return TrainingSimulator.fromJson(response);
  }

  Future<void> deleteSimulator(String id) async {
    await _supabaseService.client.from('training_simulators').delete().eq('id', id);
  }

  Future<List<TrainingExam>> getExams(String companyId) async {
    final response = await _supabaseService.client
        .from('training_exams')
        .select()
        .eq('company_id', companyId);
    return (response as List).map((x) => TrainingExam.fromJson(x)).toList();
  }

  Future<TrainingExam> createExam(Map<String, dynamic> data) async {
    final response = await _supabaseService.client
        .from('training_exams')
        .insert(data)
        .select()
        .single();
    return TrainingExam.fromJson(response);
  }

  Future<void> deleteExam(String id) async {
    await _supabaseService.client.from('training_exams').delete().eq('id', id);
  }

  Future<List<TrainingProgress>> getProgress(String companyId, {String? profileId}) async {
    var query = _supabaseService.client.from('training_progress').select().eq('company_id', companyId);
    if (profileId != null) {
      query = query.eq('profile_id', profileId);
    }
    final response = await query;
    return (response as List).map((x) => TrainingProgress.fromJson(x)).toList();
  }

  Future<TrainingProgress> logProgress(Map<String, dynamic> data) async {
    // Check if progress already logged
    final existing = await _supabaseService.client
        .from('training_progress')
        .select()
        .eq('profile_id', data['profile_id'])
        .eq('item_type', data['item_type'])
        .eq('item_id', data['item_id']);

    if ((existing as List).isNotEmpty) {
      // Update score if higher
      final currentProgress = TrainingProgress.fromJson(existing.first);
      if (data['score'] != null && (currentProgress.score == null || data['score'] > currentProgress.score!)) {
        final updated = await _supabaseService.client
            .from('training_progress')
            .update({'score': data['score'], 'completed_at': DateTime.now().toIso8601String()})
            .eq('id', currentProgress.id)
            .select()
            .single();
        return TrainingProgress.fromJson(updated);
      }
      return currentProgress;
    }

    final response = await _supabaseService.client
        .from('training_progress')
        .insert(data)
        .select()
        .single();
    return TrainingProgress.fromJson(response);
  }

  Future<List<TrainingBadge>> getBadges(String companyId, {String? profileId}) async {
    var query = _supabaseService.client.from('training_badges').select().eq('company_id', companyId);
    if (profileId != null) {
      query = query.eq('profile_id', profileId);
    }
    final response = await query;
    return (response as List).map((x) => TrainingBadge.fromJson(x)).toList();
  }

  Future<TrainingBadge> unlockBadge(String profileId, String companyId, String badgeName) async {
    final existing = await _supabaseService.client
        .from('training_badges')
        .select()
        .eq('profile_id', profileId)
        .eq('badge_name', badgeName);

    if ((existing as List).isNotEmpty) {
      return TrainingBadge.fromJson(existing.first);
    }

    final response = await _supabaseService.client
        .from('training_badges')
        .insert({
          'profile_id': profileId,
          'company_id': companyId,
          'badge_name': badgeName,
        })
        .select()
        .single();
    return TrainingBadge.fromJson(response);
  }

  // ── Gemini AI Simulator Logic ──

  Future<Map<String, dynamic>> evaluateObjectionResponse({
    required String apiKey,
    required String clientPersona,
    required String objectionType,
    required String objectionText,
    required String marketerMessage,
    required List<Map<String, String>> chatHistory,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final historyString = chatHistory
        .map((m) => '${m['sender']}: ${m['text']}')
        .join('\n');

    final prompt = '''
You are an advanced interactive Real Estate objection handling simulator.
The user is a Real Estate marketer/agent trying to close a transaction.
Your role: Act as the prospect described below.

PROSPECT PERSONA: $clientPersona
OBJECTION TYPE: $objectionType
OBJECTION TEXT: $objectionText

CHAT HISTORY SO FAR:
$historyString
User's latest message: "$marketerMessage"

Evaluate the user's latest response.
Respond in JSON format only. Do not include any markdown format tags like ```json or ```. Return pure JSON text.

JSON FORMAT SCHEMA:
{
  "customerMessage": "The prospect's next reply in character. Keep the objection realistic. If the user handled it perfectly, they are closer to closing the deal.",
  "critique": "A brief coaching tip detailing what the user did well and how they could improve (written as an AI Coach). Limit to 2 sentences.",
  "scoreDelta": 5, // Score out of 10 for the quality of this response (between 0 and 10).
  "isDone": false // Set to true if the prospect decides to buy/close the deal (score reaches 9+) OR if they walk away frustrated (3 consecutive bad responses or score under 3).
}
''';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API Error (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body);
    final text = body['candidates'][0]['content']['parts'][0]['text'] as String;
    
    // Fallback parsing just in case
    try {
      return jsonDecode(text.trim()) as Map<String, dynamic>;
    } catch (e) {
      // Regex parse fallback if JSON is wrapped in markdown
      final jsonRegex = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegex.firstMatch(text);
      if (match != null) {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      }
      throw Exception('Failed to parse Gemini response: $text');
    }
  }
}

final trainingServiceProvider = Provider<TrainingService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return TrainingService(supabaseService);
});
