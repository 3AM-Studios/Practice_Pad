import WidgetKit
import SwiftUI
import AppIntents

// Data structures - temporary until project structure is fixed
struct PracticePadEntry: TimelineEntry {
    let date: Date
    let practiceAreas: [PracticeAreaData]
    let activeSession: ActiveSessionData?
    let dailyGoal: Int
    let todaysPractice: Int
}

struct PracticeAreaData {
    let name: String
    let type: String
    let items: [PracticeItemData]
}

struct PracticeItemData {
    let id: String
    let name: String
    let description: String
    let isCompleted: Bool
    let completedCycles: Int
    let targetCycles: Int
}

struct ActiveSessionData {
    let itemName: String
    let elapsedSeconds: Int
    let targetSeconds: Int
    let isTimerRunning: Bool
    let progressPercentage: Double
    let timerStartTime: Double? // Unix timestamp when timer was started
    
    // Widget displays whatever elapsed time is stored - no dynamic calculation
    var currentElapsedSeconds: Int {
        return elapsedSeconds
    }
}

// MARK: - App Intents
struct SelectPracticeAreaIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Practice Area"
    static var description = IntentDescription("Cycles through practice area filters in the widget.")

    func perform() async throws -> some IntentResult {
        let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad")
        let currentFilter = userDefaults?.string(forKey: "selected_area_filter") ?? "all"
        
        let nextFilter: String
        switch currentFilter {
        case "all": nextFilter = "songs"
        case "songs": nextFilter = "exercises"
        case "exercises": nextFilter = "chordProgressions"
        case "chordProgressions": nextFilter = "all"
        default: nextFilter = "all"
        }
        
        userDefaults?.set(nextFilter, forKey: "selected_area_filter")
        NSLog("Widget: Cycled area filter from \(currentFilter) to \(nextFilter)")
        return .result()
    }
}

struct StartPracticeItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Practice Item"
    static var description = IntentDescription("Starts practicing a specific item.")

    @Parameter(title: "Practice Item ID")
    var itemId: String
    
    @Parameter(title: "Practice Item Name") 
    var itemName: String
    
    init(itemId: String, itemName: String) {
        self.itemId = itemId
        self.itemName = itemName
    }
    
    init() {
        self.itemId = ""
        self.itemName = ""
    }
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start practice for \(\.$itemName)")
    }

    func perform() async throws -> some IntentResult {
        NSLog("Widget: StartPracticeItemIntent.perform() called - DEBUG ENTRY POINT")
        NSLog("Widget: StartPracticeItemIntent called with itemId: '\(itemId)', itemName: '\(itemName)'")
        
        // Validate input parameters
        if itemId.isEmpty {
            NSLog("Widget: ERROR - itemId is empty!")
            return .result()
        }
        
        if itemName.isEmpty {
            NSLog("Widget: ERROR - itemName is empty!")
            return .result()
        }
        
        guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
            NSLog("Widget: ERROR - Could not access UserDefaults with app group!")
            return .result()
        }
        
        let actionData = [
            "action": "start_practice_item",
            "itemId": itemId,
            "itemName": itemName,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        NSLog("Widget: Action data to save: \(actionData)")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: actionData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            userDefaults.set(jsonString, forKey: "widget_action")
            userDefaults.synchronize()
            NSLog("Widget: Successfully saved action to widget_action key: \(jsonString)")
            
            // Trigger immediate widget reload to reflect changes
            WidgetCenter.shared.reloadTimelines(ofKind: "PracticePadWidget")
            NSLog("Widget: Triggered widget timeline reload")
        } else {
            NSLog("Widget: ERROR - Failed to serialize action data")
        }
        
        NSLog("Widget: StartPracticeItemIntent.perform() completed successfully")
        return .result()
    }
}

struct ToggleSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Practice Session"
    static var description = IntentDescription("Plays or pauses the current practice session.")

    init() {}

    func perform() async throws -> some IntentResult {
        NSLog("Widget: ToggleSessionIntent.perform() called - DEBUG ENTRY POINT")
        
        guard let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad") else {
            NSLog("Widget: ERROR - Could not access UserDefaults with app group!")
            return .result()
        }
        
        // Read current active session from UserDefaults
        var currentSessionData: [String: Any]? = nil
        if let activeSessionJson = userDefaults.string(forKey: "active_session"),
           !activeSessionJson.isEmpty,
           let activeSessionDataRaw = activeSessionJson.data(using: .utf8) {
            do {
                currentSessionData = try JSONSerialization.jsonObject(with: activeSessionDataRaw) as? [String: Any]
                NSLog("Widget: Found active session data: \(currentSessionData ?? [:])")
            } catch {
                NSLog("Widget: Error decoding active session: \(error)")
            }
        }
        
        guard var sessionData = currentSessionData else {
            NSLog("Widget: No active session found to toggle")
            return .result()
        }
        
        // Toggle the isTimerRunning state
        let currentlyRunning = sessionData["isTimerRunning"] as? Bool ?? false
        let newRunningState = !currentlyRunning
        sessionData["isTimerRunning"] = newRunningState
        
        // Widget only toggles the running state - Flutter app handles elapsed time
        NSLog("Widget: Only toggling timer state, Flutter app will handle time tracking")
        
        NSLog("Widget: Toggling timer from \(currentlyRunning) to \(newRunningState)")
        
        // Save the updated session data back to UserDefaults
        do {
            let updatedJsonData = try JSONSerialization.data(withJSONObject: sessionData)
            let updatedJsonString = String(data: updatedJsonData, encoding: .utf8) ?? ""
            userDefaults.set(updatedJsonString, forKey: "active_session")
            userDefaults.synchronize()
            NSLog("Widget: Successfully updated active session state: \(updatedJsonString)")
            
            // Immediately trigger widget timeline reload to show the state change
            WidgetCenter.shared.reloadTimelines(ofKind: "PracticePadWidget")
            NSLog("Widget: Triggered widget timeline reload to reflect state change")
            
        } catch {
            NSLog("Widget: ERROR - Failed to serialize updated session data: \(error)")
        }
        
        NSLog("Widget: ToggleSessionIntent.perform() completed successfully")
        return .result()
    }
}

// MARK: - Timeline Provider
struct PracticePadTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PracticePadEntry {
        return loadCurrentData()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PracticePadEntry) -> ()) {
        let entry = loadCurrentData()
        NSLog("Widget: getSnapshot called, returning entry with \(entry.practiceAreas.count) areas")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PracticePadEntry>) -> ()) {
        let currentDate = Date()
        let entry = loadCurrentData()
        
        // Create multiple timeline entries for real-time updates when timer is running
        var entries: [PracticePadEntry] = []
        
        if let activeSession = entry.activeSession, activeSession.isTimerRunning {
            // Create entries that reload data every second when timer is running
            NSLog("Widget: Timer is running, scheduling frequent reloads every second")
            
            // Create a few entries with 1-second intervals to force frequent reloads
            for i in 0..<5 {
                let entryDate = Calendar.current.date(byAdding: .second, value: i, to: currentDate)!
                
                // Each entry will reload current data from UserDefaults (updated by Flutter app)
                let currentEntry = loadCurrentData()
                let updatedEntry = PracticePadEntry(
                    date: entryDate,
                    practiceAreas: currentEntry.practiceAreas,
                    activeSession: currentEntry.activeSession,
                    dailyGoal: currentEntry.dailyGoal,
                    todaysPractice: currentEntry.todaysPractice
                )
                
                entries.append(updatedEntry)
            }
            
            // Schedule next reload in 5 seconds
            let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
            
        } else {
            // Update every 5 minutes when no active timer
            NSLog("Widget: No active timer, scheduling updates every 5 minutes")
            entries = [entry]
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func loadCurrentData() -> PracticePadEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad")
        
        // Load practice areas
        var practiceAreas: [PracticeAreaData] = []
        if let practiceAreasJson = userDefaults?.string(forKey: "practice_areas"),
           !practiceAreasJson.isEmpty,
           let practiceAreasData = practiceAreasJson.data(using: .utf8) {
            do {
                let decoded = try JSONSerialization.jsonObject(with: practiceAreasData) as? [[String: Any]]
                practiceAreas = decoded?.compactMap { areaDict in
                    guard let name = areaDict["name"] as? String,
                          let type = areaDict["type"] as? String,
                          let itemsArray = areaDict["items"] as? [[String: Any]] else {
                        return nil
                    }
                    
                    let items = itemsArray.compactMap { itemDict -> PracticeItemData? in
                        guard let id = itemDict["id"] as? String,
                              let name = itemDict["name"] as? String,
                              let description = itemDict["description"] as? String,
                              let isCompleted = itemDict["isCompleted"] as? Bool,
                              let completedCycles = itemDict["completedCycles"] as? Int,
                              let targetCycles = itemDict["targetCycles"] as? Int else {
                            return nil
                        }
                        
                        return PracticeItemData(
                            id: id,
                            name: name,
                            description: description,
                            isCompleted: isCompleted,
                            completedCycles: completedCycles,
                            targetCycles: targetCycles
                        )
                    }
                    
                    return PracticeAreaData(name: name, type: type, items: items)
                } ?? []
                NSLog("Widget: Loaded \(practiceAreas.count) practice areas")
                for area in practiceAreas {
                    NSLog("Widget: Area '\(area.name)' has \(area.items.count) items")
                    for item in area.items {
                        NSLog("Widget: Item ID='\(item.id)', Name='\(item.name)'")
                    }
                }
            } catch {
                NSLog("Widget: Error decoding practice areas: \(error)")
            }
        } else {
            NSLog("Widget: No practice areas data found or empty")
        }
        
        // Load active session
        var activeSession: ActiveSessionData? = nil
        if let activeSessionJson = userDefaults?.string(forKey: "active_session"),
           !activeSessionJson.isEmpty,
           let activeSessionData = activeSessionJson.data(using: .utf8) {
            do {
                if let sessionDict = try JSONSerialization.jsonObject(with: activeSessionData) as? [String: Any] {
                    activeSession = ActiveSessionData(
                        itemName: sessionDict["itemName"] as? String ?? "Unknown",
                        elapsedSeconds: sessionDict["elapsedSeconds"] as? Int ?? 0,
                        targetSeconds: sessionDict["targetSeconds"] as? Int ?? 60,
                        isTimerRunning: sessionDict["isTimerRunning"] as? Bool ?? false,
                        progressPercentage: sessionDict["progressPercentage"] as? Double ?? 0.0,
                        timerStartTime: sessionDict["timerStartTime"] as? Double
                    )
                    NSLog("Widget: Loaded active session: \(activeSession?.itemName ?? "nil")")
                }
            } catch {
                NSLog("Widget: Error decoding active session: \(error)")
            }
        } else {
            NSLog("Widget: No active session data found")
        }
        
        // Load goal and progress
        let dailyGoalString = userDefaults?.string(forKey: "daily_goal") ?? "30"
        let dailyGoal = Int(dailyGoalString) ?? 30
        let todaysPracticeString = userDefaults?.string(forKey: "todays_practice") ?? "0"
        let todaysPractice = Int(todaysPracticeString) ?? 0
        
        let finalPracticeAreas = practiceAreas
        
        NSLog("Widget: Final entry - Areas: \(finalPracticeAreas.count), Goal: \(dailyGoal), Practice: \(todaysPractice)")
        
        return PracticePadEntry(
            date: Date(),
            practiceAreas: finalPracticeAreas,
            activeSession: activeSession,
            dailyGoal: dailyGoal,
            todaysPractice: todaysPractice
        )
    }
}

struct PracticePadWidget: Widget {
    let kind: String = "PracticePadWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: PracticePadAppIntentTimelineProvider()) { entry in
            PracticePadWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Practice Pad")
        .description("Interactive practice widget with play controls")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("This is an example widget.")
}

// MARK: - App Intent Timeline Provider
struct PracticePadAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = PracticePadEntry
    typealias Intent = ConfigurationAppIntent
    
    func placeholder(in context: Context) -> PracticePadEntry {
        return loadCurrentData()
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> PracticePadEntry {
        let entry = loadCurrentData()
        NSLog("Widget: snapshot called, returning entry with \(entry.practiceAreas.count) areas")
        return entry
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<PracticePadEntry> {
        let currentDate = Date()
        let entry = loadCurrentData()
        
        // Create multiple timeline entries for real-time updates when timer is running
        var entries: [PracticePadEntry] = []
        
        if let activeSession = entry.activeSession, activeSession.isTimerRunning {
            // Create entries that reload data every second when timer is running
            NSLog("Widget: Timer is running, scheduling frequent reloads every second")
            
            // Create a few entries with 1-second intervals to force frequent reloads
            for i in 0..<5 {
                let entryDate = Calendar.current.date(byAdding: .second, value: i, to: currentDate)!
                
                // Each entry will reload current data from UserDefaults (updated by Flutter app)
                let currentEntry = loadCurrentData()
                let updatedEntry = PracticePadEntry(
                    date: entryDate,
                    practiceAreas: currentEntry.practiceAreas,
                    activeSession: currentEntry.activeSession,
                    dailyGoal: currentEntry.dailyGoal,
                    todaysPractice: currentEntry.todaysPractice
                )
                
                entries.append(updatedEntry)
            }
            
            // Schedule next reload in 5 seconds
            let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            return timeline
            
        } else {
            // Update every 5 minutes when no active timer
            NSLog("Widget: No active timer, scheduling updates every 5 minutes")
            entries = [entry]
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            return timeline
        }
    }
    
    private func loadCurrentData() -> PracticePadEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad")
        
        // Load practice areas
        var practiceAreas: [PracticeAreaData] = []
        if let practiceAreasJson = userDefaults?.string(forKey: "practice_areas"),
           !practiceAreasJson.isEmpty,
           let practiceAreasData = practiceAreasJson.data(using: .utf8) {
            do {
                let decoded = try JSONSerialization.jsonObject(with: practiceAreasData) as? [[String: Any]]
                practiceAreas = decoded?.compactMap { areaDict in
                    guard let name = areaDict["name"] as? String,
                          let type = areaDict["type"] as? String,
                          let itemsArray = areaDict["items"] as? [[String: Any]] else {
                        return nil
                    }
                    
                    let items = itemsArray.compactMap { itemDict -> PracticeItemData? in
                        guard let id = itemDict["id"] as? String,
                              let name = itemDict["name"] as? String,
                              let description = itemDict["description"] as? String,
                              let isCompleted = itemDict["isCompleted"] as? Bool,
                              let completedCycles = itemDict["completedCycles"] as? Int,
                              let targetCycles = itemDict["targetCycles"] as? Int else {
                            return nil
                        }
                        
                        return PracticeItemData(
                            id: id,
                            name: name,
                            description: description,
                            isCompleted: isCompleted,
                            completedCycles: completedCycles,
                            targetCycles: targetCycles
                        )
                    }
                    
                    return PracticeAreaData(name: name, type: type, items: items)
                } ?? []
                NSLog("Widget: Loaded \(practiceAreas.count) practice areas")
                for area in practiceAreas {
                    NSLog("Widget: Area '\(area.name)' has \(area.items.count) items")
                    for item in area.items {
                        NSLog("Widget: Item ID='\(item.id)', Name='\(item.name)'")
                    }
                }
            } catch {
                NSLog("Widget: Error decoding practice areas: \(error)")
            }
        } else {
            NSLog("Widget: No practice areas data found or empty")
        }
        
        // Load active session
        var activeSession: ActiveSessionData? = nil
        if let activeSessionJson = userDefaults?.string(forKey: "active_session"),
           !activeSessionJson.isEmpty,
           let activeSessionData = activeSessionJson.data(using: .utf8) {
            do {
                if let sessionDict = try JSONSerialization.jsonObject(with: activeSessionData) as? [String: Any] {
                    activeSession = ActiveSessionData(
                        itemName: sessionDict["itemName"] as? String ?? "Unknown",
                        elapsedSeconds: sessionDict["elapsedSeconds"] as? Int ?? 0,
                        targetSeconds: sessionDict["targetSeconds"] as? Int ?? 60,
                        isTimerRunning: sessionDict["isTimerRunning"] as? Bool ?? false,
                        progressPercentage: sessionDict["progressPercentage"] as? Double ?? 0.0,
                        timerStartTime: sessionDict["timerStartTime"] as? Double
                    )
                    NSLog("Widget: Loaded active session: \(activeSession?.itemName ?? "nil")")
                }
            } catch {
                NSLog("Widget: Error decoding active session: \(error)")
            }
        } else {
            NSLog("Widget: No active session data found")
        }
        
        // Load goal and progress
        let dailyGoalString = userDefaults?.string(forKey: "daily_goal") ?? "30"
        let dailyGoal = Int(dailyGoalString) ?? 30
        let todaysPracticeString = userDefaults?.string(forKey: "todays_practice") ?? "0"
        let todaysPractice = Int(todaysPracticeString) ?? 0
        
        let finalPracticeAreas = practiceAreas
        
        NSLog("Widget: Final entry - Areas: \(finalPracticeAreas.count), Goal: \(dailyGoal), Practice: \(todaysPractice)")
        
        return PracticePadEntry(
            date: Date(),
            practiceAreas: finalPracticeAreas,
            activeSession: activeSession,
            dailyGoal: dailyGoal,
            todaysPractice: todaysPractice
        )
    }
}

struct PracticePadWidgetEntryView: View {
    var entry: PracticePadEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with practice area filter dropdown
            HeaderView(entry: entry)
            
            // Active session banner with play/pause button
            if let activeSession = entry.activeSession {
                ActiveSessionView(session: activeSession)
            }
            
            // Practice areas with interactive elements
            PracticeAreasView(entry: entry)
            
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .containerBackground(.white, for: .widget)
    }
}

struct HeaderView: View {
    let entry: PracticePadEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Practice")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                // Practice area filter - cycling button
                Button(intent: SelectPracticeAreaIntent()) {
                    HStack {
                        Text(getSelectedAreaText())
                            .font(.caption)
                            .foregroundColor(.blue)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // Goal progress indicator
            if entry.dailyGoal > 0 {
                Text("\(entry.todaysPractice)/\(entry.dailyGoal) min")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
        }
    }
    
    private func getSelectedAreaText() -> String {
        let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad")
        let selectedFilter = userDefaults?.string(forKey: "selected_area_filter") ?? "all"
        
        switch selectedFilter {
        case "songs": return "Songs"
        case "exercises": return "Exercises"
        case "chordProgressions": return "Chord Progressions"
        default: return "All Areas"
        }
    }
}

struct ActiveSessionView: View {
    let session: ActiveSessionData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.itemName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                let minutes = session.elapsedSeconds / 60
                let seconds = session.elapsedSeconds % 60
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            // Interactive play/pause button
            Button(intent: ToggleSessionIntent()) {
                Image(systemName: session.isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(session.isTimerRunning ? "Pause session" : "Play session")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue)
        )
    }
}

struct PracticeAreasView: View {
    let entry: PracticePadEntry
    
    var body: some View {
        let filteredAreas = getFilteredAreas()
        
        if !filteredAreas.isEmpty {
            VStack(spacing: 10) {
                ForEach(filteredAreas.prefix(2), id: \.name) { area in
                    PracticeAreaView(area: area)
                }
                
                if filteredAreas.count > 2 {
                    Text("+ \(filteredAreas.count - 2) more areas")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.gray)
                Text("No practice areas for today")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
    
    private func getFilteredAreas() -> [PracticeAreaData] {
        let userDefaults = UserDefaults(suiteName: "group.com.example.practicePad")
        let selectedFilter = userDefaults?.string(forKey: "selected_area_filter") ?? "all"
        
        guard selectedFilter != "all" else { return entry.practiceAreas }
        
        return entry.practiceAreas.filter { area in
            switch selectedFilter {
            case "songs": return area.type.lowercased() == "song"
            case "exercises": return area.type.lowercased() == "exercise"
            case "chordProgressions": return area.type.lowercased() == "chordprogression"
            default: return true
            }
        }
    }
}

struct PracticeAreaView: View {
    let area: PracticeAreaData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Area header
            HStack {
                Text(area.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
            
            
            }
            
            // Practice items (show up to 3 items)
            VStack(spacing: 6) {
                ForEach(area.items.prefix(3), id: \.id) { item in
                    PracticeItemRowView(item: item)
                }
                
                if area.items.count > 3 {
                    Text("+ \(area.items.count - 3) more items")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, 10)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .background(Color.white)
        )
    }
}

struct PracticeItemRowView: View {
    let item: PracticeItemData
    
    var body: some View {
        HStack {
            Text(item.name)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Spacer()
            
            // Cycle count
            if item.targetCycles > 1 {
                Text("\(item.completedCycles)/\(item.targetCycles)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Play button
            Button(intent: StartPracticeItemIntent(itemId: item.id, itemName: item.name)) {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Start practice for \(item.name)")
        }
    }
}