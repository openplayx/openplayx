import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/conversation/assistant_store.dart';
import 'package:openplayx/assistant/model/langchain_model.dart';
import 'package:openplayx/assistant/model/model_probe.dart';

void main() {
  test(
    'platform defaults support replies and tools through the App SDK',
    () async {
      final model = LangChainModel(
        apiKey: 'platform',
        endpoint: AssistantConfig.platformEndpoint,
        model: AssistantConfig.platformModel,
        maxTokens: 2048,
      );
      expect(await ModelProbe.replies(model), true);
      expect(await ModelProbe.callsTools(model), true);
    },
    skip: !const bool.fromEnvironment('LIVE_PLATFORM'),
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
