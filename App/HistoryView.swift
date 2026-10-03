import Charts
import SwiftData
import SwiftUI
import UIKit

struct DayStat {
    var focus = 0
    var deep = 0
    var sessions = 0
}

struct HistoryView: View {
    @Query(sort: \FocusSession.start) private var sessions: [FocusSession]
    @Query private var notes: [DayNote]
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Date?
    @State private var tab: Tab = .overview

    private enum Tab: String, CaseIterable { case overview = "Overview", calendar = "Calendar" }

    private let cal = Calendar.current

    var body: some View {
        let stats = byDay
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SheetHeader(done: { dismiss() }) { NotebookTitle() }
                    TabPicker(selection: $tab)
                    switch tab {
                    case .overview:
                        // Big picture first, then the patterns.
                        WeekSummary(stats: stats)
                        Card(title: "All time") { AllTime(stats: stats) }
                        Card(title: "Last 7 days") { WeekChart(stats: stats) }
                        Card(title: "When you focus") { TimeOfDay(sessions: sessions) }
                    case .calendar:
                        // Day by day: tap any day for its sessions and a note.
                        Card(title: "Recent weeks") {
                            Heatmap(stats: stats, selected: $selected)
                            Legend()
                            if let day = selected {
                                DayDetail(day: day, stat: stats[day], sessions: daySessions[day] ?? []).transition(.opacity)
                            }
                        }
                        Card(title: "Month by month") {
                            MonthList(stats: stats, sessions: daySessions, noteDays: Set(notes.filter { !$0.text.isEmpty }.map(\.day)))
                        }
                    }
                }
                .padding(20)
                .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
            }
            .scrollDismissesKeyboard(.interactively)
            #if DEBUG
            .task { if ProcessInfo.processInfo.arguments.contains("-openMonth") { tab = .calendar } }
            .defaultScrollAnchor(ProcessInfo.processInfo.arguments.contains("-scrollBottom") ? .bottom : .top)
            #endif
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var daySessions: [Date: [FocusSession]] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.start) }
    }

    private var byDay: [Date: DayStat] {
        var result: [Date: DayStat] = [:]
        for session in sessions {
            let day = cal.startOfDay(for: session.start)
            result[day, default: DayStat()].focus += session.seconds
            if session.deep { result[day, default: DayStat()].deep += session.seconds }
            if session.completed { result[day, default: DayStat()].sessions += 1 }
        }
        return result
    }
}

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))
                .foregroundStyle(Theme.ink)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: Week summary

private struct WeekSummary: View {
    let stats: [Date: DayStat]

    var body: some View {
        let cal = Calendar.current
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: .now)!.start
        let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
        let now = sum(from: thisWeek, days: 7)
        let before = sum(from: lastWeek, days: 7)

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This week")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(Format.duration(now.focus))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(comparison(now.focus, before.focus))
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(now.focus >= before.focus ? Theme.caramel : Theme.inkSoft)
                if now.deep > 0 {
                    Text("\(Format.duration(now.deep)) of deep focus")
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            KittyView(mood: now.focus > 0 ? .happy : .idle)
                .frame(width: 96, height: 96)
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sum(from start: Date, days: Int) -> DayStat {
        let cal = Calendar.current
        var total = DayStat()
        for i in 0..<days {
            guard let day = cal.date(byAdding: .day, value: i, to: start), let s = stats[day] else { continue }
            total.focus += s.focus
            total.deep += s.deep
            total.sessions += s.sessions
        }
        return total
    }

    private func comparison(_ now: Int, _ before: Int) -> String {
        if now == 0 && before == 0 { return "Nothing here yet 🐾" }
        if before == 0 { return "Fresh week" }
        let diff = now - before
        if abs(diff) < 60 { return "Same as last week" }
        return diff > 0 ? "\(Format.duration(diff)) more than last week" : "\(Format.duration(-diff)) less than last week"
    }
}

// MARK: 7-day chart

private struct WeekChart: View {
    let stats: [Date: DayStat]

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }

        Chart {
            ForEach(days, id: \.self) { day in
                let stat = stats[day] ?? DayStat()
                BarMark(x: .value("Day", day, unit: .day), y: .value("Minutes", stat.deep / 60))
                    .foregroundStyle(by: .value("Kind", "Deep focus"))
                    .cornerRadius(5)
                BarMark(x: .value("Day", day, unit: .day), y: .value("Minutes", (stat.focus - stat.deep) / 60))
                    .foregroundStyle(by: .value("Kind", "Other focus"))
                    .cornerRadius(5)
            }
        }
        .chartForegroundStyleScale(["Deep focus": Theme.caramel, "Other focus": Theme.caramel.opacity(0.35)])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel { if let m = value.as(Int.self) { Text("\(m)m") } }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 170)
    }
}

// MARK: Heatmap

private struct Heatmap: View {
    let stats: [Date: DayStat]
    @Binding var selected: Date?
    private let weeks = 16

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: today)!.start
        let first = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)!

        HStack(alignment: .top, spacing: 4) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = cal.date(byAdding: .day, value: week * 7 + weekday, to: first)!
                        cell(day: day, future: day > today)
                    }
                }
            }
        }
    }

    private func cell(day: Date, future: Bool) -> some View {
        let isSelected = selected == day
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(future ? Color.clear : Theme.heat[heatLevel(stats[day]?.focus ?? 0)])
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.ink, lineWidth: 2)
                }
            }
            .scaleEffect(isSelected ? 1.15 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !future else { return }
                Haptics.select()
                selected = isSelected ? nil : day
            }
    }

}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
            ForEach(Theme.heat.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3).fill(Theme.heat[i]).frame(width: 12, height: 12)
            }
            Text("More")
            Spacer()
            Text("16 weeks")
        }
        .font(.rounded(.caption))
        .foregroundStyle(Theme.inkSoft)
    }
}

private struct DayDetail: View {
    let day: Date
    let stat: DayStat?
    let sessions: [FocusSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day, format: .dateTime.weekday(.wide).month().day())
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if let stat, stat.focus > 0 {
                    Text("\(Format.duration(stat.focus)) focus · \(Format.duration(stat.deep)) deep")
                } else {
                    Text("A rest day 😴")
                }
            }
            if !sessions.isEmpty {
                SessionList(sessions: sessions)
            }
            DayNoteField(day: day).id(day)
        }
        .font(.rounded(.subheadline))
        .foregroundStyle(Theme.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// When it started, how long, and how it went, as aligned columns.
private struct SessionList: View {
    let sessions: [FocusSession]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            ForEach(sessions) { session in
                GridRow {
                    Circle()
                        .fill(session.deep ? Theme.caramel : Theme.caramel.opacity(0.35))
                        .frame(width: 8, height: 8)
                    Text(session.start, format: .dateTime.hour().minute())
                        .foregroundStyle(Theme.ink)
                    Text(Format.duration(max(60, session.seconds)))
                        .foregroundStyle(Theme.ink)
                        .gridColumnAlignment(.trailing)
                    Text(session.deep ? "deep" : session.completed ? "finished" : "stopped early")
                        .font(.rounded(.caption, weight: .medium))
                        .foregroundStyle(session.deep ? Theme.caramel : Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .monospacedDigit()
                .accessibilityElement(children: .combine)
            }
        }
        .font(.rounded(.subheadline))
    }
}

/// A short note about the day. Saves as she types; clearing it removes it.
private struct DayNoteField: View {
    let day: Date
    static let maxLength = 200

    @Environment(\.modelContext) private var context
    @Query private var notes: [DayNote]
    @State private var text = ""

    init(day: Date) {
        self.day = day
        let target = day
        _notes = Query(filter: #Predicate<DayNote> { $0.day == target })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "pencil.line")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.caramel)
                .frame(height: 20)
            TextField("Add a note about this day", text: $text, axis: .vertical)
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
                .tint(Theme.caramel)
                .lineLimit(1...4)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { hideKeyboard() }
                            .fontWeight(.semibold)
                            .tint(Theme.caramel)
                    }
                }
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear { text = notes.first?.text ?? "" }
        .onChange(of: text) { _, newValue in
            if newValue.count > Self.maxLength { text = String(newValue.prefix(Self.maxLength)); return }
            save(newValue)
        }
    }

    private func save(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note = notes.first {
            if trimmed.isEmpty { context.delete(note) } else { note.text = trimmed }
        } else if !trimmed.isEmpty {
            context.insert(DayNote(day: day, text: trimmed))
        }
        try? context.save()
    }
}

// MARK: When you focus

/// Focus time by part of the day, based on when each session started.
private struct TimeOfDay: View {
    let sessions: [FocusSession]

    private struct Part: Identifiable {
        let id: String
        let icon: String
        let hours: [Int]
    }

    private let parts = [
        Part(id: "Morning", icon: "sunrise.fill", hours: Array(5...11)),
        Part(id: "Afternoon", icon: "sun.max.fill", hours: Array(12...16)),
        Part(id: "Evening", icon: "sunset.fill", hours: Array(17...20)),
        Part(id: "Night", icon: "moon.stars.fill", hours: [21, 22, 23, 0, 1, 2, 3, 4]),
    ]

    var body: some View {
        let cal = Calendar.current
        let totals = parts.map { part in
            sessions.filter { part.hours.contains(cal.component(.hour, from: $0.start)) }.reduce(0) { $0 + $1.seconds }
        }
        let most = max(1, totals.max() ?? 1)
        VStack(alignment: .leading, spacing: 14) {
            Text(headline(totals))
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(parts.enumerated()), id: \.element.id) { index, part in
                    let share = CGFloat(totals[index]) / CGFloat(most)
                    VStack(spacing: 6) {
                        Text(totals[index] >= 10 * 3600 ? "\(totals[index] / 3600)h" : Format.duration(totals[index]))
                            .font(.rounded(.caption, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(totals[index] == 0 ? Theme.track : Theme.caramel)
                            .frame(width: 34, height: totals[index] == 0 ? 6 : max(10, 70 * share))
                        Image(systemName: part.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.caramel)
                        Text(part.id)
                            .font(.rounded(.caption, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
        }
    }

    private func headline(_ totals: [Int]) -> String {
        guard sessions.count >= 5, let best = totals.indices.max(by: { totals[$0] < totals[$1] }), totals[best] > 0 else {
            return "Check back after a few more sessions."
        }
        switch best {
        case 0: return "Mornings are your thing"
        case 1: return "Afternoons are your thing"
        case 2: return "Evenings are your thing"
        default: return "Night owl focus"
        }
    }
}

/// Heatmap shade for a day's focus: 0 (none) to 4 (two hours or more).
private func heatLevel(_ seconds: Int) -> Int {
    switch seconds / 60 {
    case 0: return 0
    case ..<25: return 1
    case ..<60: return 2
    case ..<120: return 3
    default: return 4
    }
}

// MARK: All time

private struct AllTime: View {
    let stats: [Date: DayStat]

    private enum Stat { case focused, deep, sessions, streak }
    @State private var selected: Stat = .focused

    var body: some View {
        let total = stats.values.reduce(into: DayStat()) {
            $0.focus += $1.focus; $0.deep += $1.deep; $0.sessions += $1.sessions
        }
        let streak = streaks
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                tile(.focused, value: Format.duration(total.focus), label: "focused")
                tile(.deep, value: Format.duration(total.deep), label: "deep focus")
                tile(.sessions, value: "\(total.sessions)", label: total.sessions == 1 ? "session" : "sessions")
                tile(.streak, value: "\(streak.current)", label: "day streak")
            }
            // Always two lines tall, so switching tiles never shifts the layout.
            Text(description(total: total, streak: streak))
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: selected)
        }
    }

    private func tile(_ stat: Stat, value: String, label: String) -> some View {
        let isOn = selected == stat
        return Button {
            Haptics.select()
            selected = stat
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(label)
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(isOn ? Theme.caramel : Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isOn ? Theme.caramel.opacity(0.16) : Theme.background,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? Theme.caramel : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(SquishStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func description(total: DayStat, streak: (current: Int, since: Date?, best: Int)) -> String {
        let firstDay = stats.filter { $0.value.focus > 0 }.keys.min()
        switch selected {
        case .focused:
            guard let firstDay else { return "Your total focus time will add up here." }
            return "\(Format.duration(total.focus)) of focus since \(firstDay.formatted(.dateTime.month(.abbreviated).day().year())), including sessions you stopped early."
        case .deep:
            return "\(Format.duration(total.deep)) from sessions you finished without pausing. Your heads-down time."
        case .sessions:
            return total.sessions == 1 ? "1 session finished start to end." : "\(total.sessions) sessions finished start to end."
        case .streak:
            let best = streak.best == 1 ? "1 day" : "\(streak.best) days"
            if streak.current > 0, let since = streak.since {
                let run = streak.current == 1 ? "1 day" : "\(streak.current) days in a row"
                return "\(run) with focus, since \(since.formatted(.dateTime.month(.abbreviated).day())). Best: \(best)."
            }
            return streak.best > 0 ? "No streak right now. Focus today to start one. Best: \(best)." : "Focus on a day to start a streak."
        }
    }

    /// The current run of focus days (ending today or yesterday), when it began, and the best run ever.
    private var streaks: (current: Int, since: Date?, best: Int) {
        let cal = Calendar.current
        let days = Set(stats.filter { $0.value.focus > 0 }.keys)
        var best = 0, run = 0
        var previous: Date?
        for day in days.sorted() {
            if let previous, cal.date(byAdding: .day, value: 1, to: previous) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = day
        }
        let today = cal.startOfDay(for: .now)
        var cursor = days.contains(today) ? today : cal.date(byAdding: .day, value: -1, to: today)!
        var current = 0
        var since: Date?
        while days.contains(cursor) {
            current += 1
            since = cursor
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (current, since, best)
    }
}

// MARK: Month by month

private struct MonthList: View {
    let stats: [Date: DayStat]
    let sessions: [Date: [FocusSession]]
    let noteDays: Set<Date>
    @State private var open: Date?
    @State private var selected: Date?

    var body: some View {
        let months = monthly
        let most = max(1, months.map(\.stat.focus).max() ?? 1)
        if months.isEmpty {
            Text("Your months will fill in here as you focus 🐾")
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.inkSoft)
        } else {
            VStack(spacing: 0) {
                ForEach(months, id: \.start) { month in
                    let isOpen = open == month.start
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            open = isOpen ? nil : month.start
                            selected = nil
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(month.start, format: .dateTime.month(.wide).year())
                                    .font(.rounded(.body, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(Format.duration(month.stat.focus)) · \(month.stat.sessions)")
                                    .font(.rounded(.subheadline, weight: .medium))
                                    .foregroundStyle(Theme.inkSoft)
                                    .monospacedDigit()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.inkSoft)
                                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                            }
                            GeometryReader { geo in
                                Capsule().fill(Theme.track)
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(Theme.caramel)
                                            .frame(width: max(6, geo.size.width * CGFloat(month.stat.focus) / CGFloat(most)))
                                    }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(month.start.formatted(.dateTime.month(.wide).year())), \(Format.duration(month.stat.focus)), \(month.stat.sessions) sessions")

                    if isOpen {
                        VStack(spacing: 10) {
                            MonthCalendar(month: month.start, stats: stats, noteDays: noteDays, selected: $selected)
                            if let day = selected {
                                DayDetail(day: day, stat: stats[day], sessions: sessions[day] ?? []).transition(.opacity)
                            }
                        }
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if month.start != months.last?.start { Divider() }
                }
            }
            #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-openMonth") { open = months.dropFirst().first?.start }
            }
            #endif
        }
    }

    /// Every month from her first session to now, newest first.
    private var monthly: [(start: Date, stat: DayStat)] {
        let cal = Calendar.current
        guard let first = stats.keys.min(),
              var month = cal.dateInterval(of: .month, for: first)?.start,
              let now = cal.dateInterval(of: .month, for: .now)?.start
        else { return [] }
        var totals: [Date: DayStat] = [:]
        for (day, stat) in stats {
            guard let start = cal.dateInterval(of: .month, for: day)?.start else { continue }
            totals[start, default: DayStat()].focus += stat.focus
            totals[start, default: DayStat()].sessions += stat.sessions
        }
        var result: [(Date, DayStat)] = []
        while month <= now {
            result.append((month, totals[month] ?? DayStat()))
            guard let next = cal.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result.reversed()
    }
}

private struct MonthCalendar: View {
    let month: Date
    let stats: [Date: DayStat]
    let noteDays: Set<Date>
    @Binding var selected: Date?

    /// One grid slot: a weekday letter, an empty lead-in, or a day of the month.
    private enum Cell: Identifiable {
        case weekday(Int, String), blank(Int), day(Int, Date)
        var id: String {
            switch self {
            case .weekday(let i, _): return "w\(i)"
            case .blank(let i): return "b\(i)"
            case .day(let n, _): return "d\(n)"
            }
        }
    }

    private var cells: [Cell] {
        let cal = Calendar.current
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let leading = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let symbols = cal.veryShortWeekdaySymbols
        let weekdays = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
        return weekdays.enumerated().map { .weekday($0.offset, $0.element) }
            + (0..<leading).map { .blank($0) }
            + (1...count).compactMap { n in cal.date(byAdding: .day, value: n - 1, to: month).map { .day(n, $0) } }
    }

    var body: some View {
        let today = Calendar.current.startOfDay(for: .now)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
            ForEach(cells) { cell in
                switch cell {
                case .weekday(_, let symbol):
                    Text(symbol)
                        .font(.rounded(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                case .blank:
                    Color.clear.aspectRatio(1, contentMode: .fit)
                case .day(let number, let day):
                    dayCell(number, day, future: day > today)
                }
            }
        }
    }

    /// Readable on every shade, in light and dark mode: dark brown on the light squares,
    /// white on the dark ones, and normal text on empty days.
    private func dayNumberColor(level: Int, future: Bool) -> Color {
        switch level {
        case 0: return Theme.ink.opacity(future ? 0.3 : 1)
        case 1, 2: return Color(hex: 0x4A3222)
        default: return Color.white
        }
    }

    private func dayCell(_ number: Int, _ day: Date, future: Bool) -> some View {
        let level = heatLevel(stats[day]?.focus ?? 0)
        let isSelected = selected == day
        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(future ? Color.clear : Theme.heat[level])
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Text("\(number)")
                    .font(.rounded(.caption, weight: .semibold))
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(dayNumberColor(level: level, future: future))
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Theme.ink, lineWidth: 2)
                }
            }
            .overlay(alignment: .bottom) {
                if noteDays.contains(day) {
                    Circle().fill(dayNumberColor(level: level, future: false)).frame(width: 4, height: 4).padding(.bottom, 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !future else { return }
                Haptics.select()
                selected = isSelected ? nil : day
            }
    }
}

/// Overview / Calendar switch at the top of the notebook.
private struct TabPicker<Tab: RawRepresentable & CaseIterable & Hashable>: View where Tab.RawValue == String, Tab.AllCases: RandomAccessCollection {
    @Binding var selection: Tab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let isOn = tab == selection
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(isOn ? Color.white : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isOn { Capsule().fill(Theme.caramel).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
    }
}

@MainActor
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
