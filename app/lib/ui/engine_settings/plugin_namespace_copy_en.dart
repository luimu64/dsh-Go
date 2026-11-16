// English titles and enum labels for popular plugins: the counterpart of
// `plugin_namespace_copy_zh.dart`, checked against the same published
// versions. Copy only: no defaults, aliases or units; the Chinese table keeps
// its values and this one never replaces them.
import 'schema_fields.dart';

const pluginNamespaceTitlesEn = <String, String>{
  'dsh-context': 'Context management',
  'imagegen': 'Image generation workspace',
  'auto-review': 'AI auto review',
  'furongjun1999-dsh-memory': 'Lingshu memory',
  'agent-teams': 'Agent teams',
  'mobile-access': 'Mobile access',
  'anime-find': 'Anime search',
  'dsh-media': 'Images and video',
  'univer': 'Sheets and documents',
  'speech-to-text-sensevoice': 'SenseVoice local recognition',
};

const pluginNamespaceCopyEn = <String, Map<String, FieldCopy>>{
  // dsh-context 0.78.2; bundle row: dsh-context.
  'dsh-context': {
    'maxRequestSteps': FieldCopy(label: 'Request steps kept'),
    'maxKeptTurns': FieldCopy(label: 'Turns kept'),
    'maxEvents': FieldCopy(label: 'Events kept'),
    'maxNodes': FieldCopy(label: 'Nodes kept'),
    'maxArchiveNodes': FieldCopy(label: 'Archived nodes kept'),
    'maxFileOps': FieldCopy(label: 'File operations kept'),
    'maxCommands': FieldCopy(label: 'Commands kept'),
    'maxCommandChars': FieldCopy(label: 'Command characters kept'),
    'defaultPlacement': FieldCopy(
      label: 'Context panel entry',
      choices: {'all': 'All', 'tab': 'Tab', 'sidebar': 'Sidebar', 'hide': 'Hide'},
    ),
    'defaultGranularity': FieldCopy(label: 'Trend chart · Granularity', choices: {'step': 'Step', 'turn': 'Turn'}),
    'defaultTrendMode': FieldCopy(label: 'Trend chart · Display', choices: {'total': 'Total', 'delta': 'Delta'}),
    'defaultDeltaBase': FieldCopy(label: 'Context browser · Compare with', choices: {'step': 'Step', 'turn': 'Turn'}),
    'defaultToolSort': FieldCopy(
      label: 'Tool definitions · Sort',
      choices: {'size': 'By size', 'count': 'By count', 'name': 'By name'},
    ),
    'defaultFileSort': FieldCopy(
      label: 'File activity · Sort',
      choices: {'count': 'By count', 'lines': 'By lines', 'latest': 'By latest', 'path': 'By path', 'name': 'By name'},
    ),
    'insightsEntry': FieldCopy(label: 'Context insights', choices: {'show': 'Show', 'hide': 'Hide'}),
    'defaultDurationCurve': FieldCopy(label: 'Trend chart · Duration curve', choices: {'show': 'Show', 'hide': 'Hide'}),
    'overviewAutoSteps': FieldCopy(
      label: 'Trend chart · Auto overview',
      choices: {'100': '100 steps', '200': '200 steps', '300': '300 steps', 'off': 'Off'},
    ),
    'defaultOverviewRange': FieldCopy(
      label: 'Context insights · Default range',
      choices: {'today': 'Today', '7d': 'Last 7 days', '30d': 'Last 30 days', 'all': 'All'},
    ),
    'fleetTab': FieldCopy(label: 'Fleet tab', choices: {'show': 'Show', 'hide': 'Hide'}),
    'promptPrefix': FieldCopy(label: 'System prompt prefix', hint: 'Prepended to the system prompt'),
    'promptSuffix': FieldCopy(label: 'System prompt suffix', hint: 'Appended to the system prompt'),
  },
  // @dickpy/dsh-imagegen 1.10.0; bundle row: imagegen.
  'imagegen': {
    'enabled': FieldCopy(label: 'Enable plugin', hint: 'Turns the image panel off'),
    'announceToAgent': FieldCopy(label: 'Announce to the agent', hint: 'Adds the ability to the prompt'),
    'allowAgentImageGeneration': FieldCopy(
      label: 'Allow agent image generation',
      hint: 'The sidebar workspace is unaffected',
    ),
    'channels': FieldCopy(label: 'Provider channels', hint: 'Image services and models'),
    'defaultChannelId': FieldCopy(label: 'Default channel ID'),
    'defaultModel': FieldCopy(label: 'Default model'),
    'promptApiUrl': FieldCopy(label: 'Chat API URL'),
    'promptApiKey': FieldCopy(label: 'Chat API key (optional)'),
    'promptModel': FieldCopy(label: 'Chat model'),
    'localStoragePath': FieldCopy(label: 'Local image folder'),
    'storageEnabled': FieldCopy(label: 'Enable object storage sync', hint: 'Local images sync in the background'),
    'storageEndpoint': FieldCopy(label: 'Endpoint URL (with bucket)'),
  },
  // dsh-auto-review 0.15.0; bundle row: auto-review.
  'auto-review': {
    'enableByDefault': FieldCopy(label: 'Enable auto review by default'),
    'toolsPolicy.default': FieldCopy(
      label: 'Default tool review policy',
      hint: 'For tools without their own setting',
      choices: {'ai': 'Reviewed by AI', 'human': 'Reviewed by a person', 'never': 'Deny approval requests'},
    ),
    'reviewerModel': FieldCopy(label: 'Reviewer model'),
    'reviewerModelProvider': FieldCopy(label: 'Reviewer model provider'),
    'reviewerTimeoutMs': FieldCopy(label: 'Review timeout'),
    'reviewerGuidance': FieldCopy(label: 'Review guidance'),
    'maxReviewsPerTurn': FieldCopy(label: 'Review limit per turn'),
    'maxFailuresPerTurn': FieldCopy(label: 'Failure limit per turn'),
    'contextBudget.turns': FieldCopy(label: 'Review context turns'),
    'contextBudget.maxChars': FieldCopy(label: 'Review context character limit'),
    'language': FieldCopy(label: 'Review language', choices: {'en': 'English', 'zh': 'Chinese'}),
  },
  // @furongjun1999/dsh-memory 0.9.17; bundle row: furongjun1999-dsh-memory.
  'furongjun1999-dsh-memory': {
    'serverName': FieldCopy(label: 'Memory server name'),
    'python': FieldCopy(label: 'Python program path'),
    'dbPath': FieldCopy(label: 'Memory database path'),
    'identity': FieldCopy(label: 'Identity name'),
    'toolAliases': FieldCopy(label: 'Legacy tool aliases', hint: 'Keep the old tool names as aliases'),
    'memory.userMessage': FieldCopy(label: 'Store user messages as memory'),
    'memory.assistantMessage': FieldCopy(label: 'Store assistant messages as memory'),
    'memory.toolResult': FieldCopy(label: 'Store tool results as memory'),
    'memory.autoRecall': FieldCopy(label: 'Recall memories automatically'),
    'memory.autoRecallLimit': FieldCopy(label: 'Auto recall limit'),
    'memory.contextWindow.enabled': FieldCopy(
      label: 'Short-term chat window',
      hint: 'Window records and context injection',
    ),
    'memory.contextWindow.turns': FieldCopy(label: 'Window records kept', hint: 'Counted in records, not turns'),
    'toolCallTimeoutMs': FieldCopy(label: 'Tool call timeout'),
  },
  // @nanmicoder/dsh-agent-teams 0.1.27; bundle row: agent-teams.
  'agent-teams': {
    'stateDir': FieldCopy(label: 'Team state folder', hint: 'Holds team and message state'),
    'memberProvider': FieldCopy(label: 'Member launch method'),
    'memberModel': FieldCopy(label: 'Member model'),
    'memberLlmProvider': FieldCopy(label: 'Member model provider'),
    'executionPrompt': FieldCopy(label: 'Member execution prompt'),
    'maxMembers': FieldCopy(label: 'Member limit'),
    'memberMaxDepth': FieldCopy(label: 'Member subagent depth limit', hint: '0 means no further subagents'),
    'profiles': FieldCopy(label: 'Team profiles'),
    'slashCommand': FieldCopy(label: 'Slash command entry'),
  },
  // dsh-mobile 0.7.0; bundle row: mobile-access.
  'mobile-access': {
    'listenHost': FieldCopy(label: 'Listen address'),
    'listenPort': FieldCopy(label: 'Listen port'),
    'publicOrigin': FieldCopy(label: 'Public access URL'),
    'upstreamOrigin': FieldCopy(label: 'Upstream service URL'),
    'setupFile': FieldCopy(label: 'Access setup file'),
    'stateFile': FieldCopy(label: 'Device state file'),
    'customCssFile': FieldCopy(label: 'Custom style file'),
    'customScriptFile': FieldCopy(label: 'Custom script file'),
    'maxDevices': FieldCopy(label: 'Device limit'),
    'maxSessions': FieldCopy(label: 'Session limit'),
    'maxConnections': FieldCopy(label: 'Connection limit'),
    'upstreamTimeoutMs': FieldCopy(label: 'Upstream request timeout'),
  },
  // @cocofhu/anime-find 0.1.12; bundle row: anime-find.
  'anime-find': {
    'mikanHost': FieldCopy(label: 'Mikan site'),
    'anibtHost': FieldCopy(label: 'AniBT site'),
    'gardenHost': FieldCopy(label: 'AnimeGarden API'),
    'timeoutMs': FieldCopy(label: 'Upstream request timeout'),
    'userAgent': FieldCopy(label: 'Request user agent'),
    'maxResults': FieldCopy(label: 'Search result limit'),
    'sources': FieldCopy(label: 'Enabled search sources'),
    'streamEnabled': FieldCopy(label: 'Enable streaming playback'),
    'streamRules': FieldCopy(label: 'Streaming rules', hint: 'CSS, XPath or a resolver script'),
  },
  // @ccch1mneyyy/dsh-media 0.2.1; bundle row: dsh-media.
  'dsh-media': {
    'services': FieldCopy(label: 'Media services'),
    'defaults.serviceId': FieldCopy(label: 'Default service ID', hint: 'Empty uses the first service set up'),
    'defaults.modelId': FieldCopy(label: 'Default model ID', hint: 'Empty uses the first model of that service'),
    'limits.maxVideoBytes': FieldCopy(label: 'Video source size limit'),
    'limits.maxImages': FieldCopy(label: 'Images per request limit'),
    'limits.maxImageBytes': FieldCopy(label: 'Image source size limit'),
    'limits.maxResponseBytes': FieldCopy(label: 'Service response size limit'),
    'limits.maxTotalImageBytes': FieldCopy(label: 'Total source size per request'),
  },
  // dsh-univer-office 0.3.9; bundle row: univer.
  'univer': {
    'autoOpenLivePreview': FieldCopy(label: 'Open live preview automatically'),
    'conversationReviewCards': FieldCopy(label: 'Chat review cards'),
    'gatewayPort': FieldCopy(label: 'Collab gateway port'),
    'autoStartGateway': FieldCopy(label: 'Start collab gateway automatically'),
    'gatewayStartupTimeoutMs': FieldCopy(label: 'Gateway startup timeout'),
    'gatewayRequestTimeoutMs': FieldCopy(label: 'Gateway request timeout'),
    'screenshotMaxPages': FieldCopy(label: 'Screenshot page limit'),
    'screenshotMaxPixels': FieldCopy(label: 'Screenshot pixel limit'),
    'browserExecutablePath': FieldCopy(label: 'Browser program path'),
    'resourceCacheRoot': FieldCopy(label: 'Resource cache folder'),
  },
  // @deepseek-ai/dsh-experimental-speech-to-text-sensevoice unknown (its bundle is 0.2.1-rc.4); bundle row: speech-to-text-sensevoice.
  'speech-to-text-sensevoice': {
    'providerId': FieldCopy(label: 'Recognition service ID'),
    'dataRoot': FieldCopy(label: 'Recognition service data folder'),
    'modelDirectory': FieldCopy(label: 'Model folder'),
    'vadModelPath': FieldCopy(label: 'Voice activity model path'),
    'precision': FieldCopy(label: 'Model precision', choices: {'int8': 'INT8 quantized', 'fp32': 'FP32 float'}),
    'threads': FieldCopy(label: 'Recognition threads'),
    'maxAudioBytes': FieldCopy(label: 'Recording size limit'),
    'inferenceTimeoutMs': FieldCopy(label: 'Recognition timeout'),
  },
};
