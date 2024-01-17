//
//  StatusItemViewModel.swift
//  Calendr
//
//  Created by Paker on 18/01/21.
//

import Cocoa
import RxSwift

class StatusItemViewModel {

    // only for unit tests
//    let iconsAndText: Observable<([NSImage], String)>

    let image: Observable<NSImage>
    let title: Observable<String>

    init(
        dateChanged: Observable<Void>,
        nextEventCalendars: Observable<[String]>,
        settings: StatusItemSettings,
        dateProvider: DateProviding,
        screenProvider: ScreenProviding,
        calendarService: CalendarServiceProviding,
        notificationCenter: NotificationCenter,
        scheduler: SchedulerType
    ) {

        let hasBirthdaysObservable = nextEventCalendars
            .repeat(when: dateChanged)
            .repeat(when: calendarService.changeObservable)
            .flatMapLatest { calendars in
                let date = dateProvider.now
                let start = dateProvider.calendar.startOfDay(for: date)
                let end = dateProvider.calendar.endOfDay(for: date)
                return calendarService
                    .events(from: start, to: end, calendars: calendars)
                    .map { $0.contains(where: \.type.isBirthday) }
            }

        let localeChangeObservable = notificationCenter.rx
            .notification(NSLocale.currentLocaleDidChangeNotification)
            .void()

        self.title = Observable
            .combineLatest(
                settings.showStatusItemDate,
                settings.statusItemDateStyle,
                settings.statusItemDateFormat
            )
            .repeat(when: localeChangeObservable)
            .flatMapLatest { showDate, style, format -> Observable<String> in

                guard showDate else { return .just("") }

                let formatter = DateFormatter(calendar: dateProvider.calendar)

                let ticker: Observable<Void>

                if style.isCustom {
                    formatter.dateFormat = format
                    if dateFormatContainsTime(format) {
                        ticker = Observable<Int>.interval(.seconds(1), scheduler: scheduler).void()
                    } else {
                        ticker = dateChanged
                    }
                } else {
                    formatter.dateStyle = style
                    ticker = dateChanged
                }

                return ticker.startWith(()).map {
                    let text = formatter.string(from: dateProvider.now)
                    return text.isEmpty ? "???" : text
                }
            }
            .distinctUntilChanged()
            .share(replay: 1)

        let icons = Observable.combineLatest(
            self.title,
            settings.showStatusItemIcon,
            settings.statusItemIconStyle,
            hasBirthdaysObservable
        )
        .map { title, showIcon, iconStyle, hasBirthdays in

            let showDate = !title.isEmpty

            var icons: [NSImage] = []

            let iconSize: CGFloat = showDate ? 15 : 16

            if hasBirthdays {
                icons.append(Icons.Event.birthday.with(pointSize: iconSize - 2))
            }

            let isEmpty = !showIcon && !showDate && !hasBirthdays
            let showIcon = showIcon || isEmpty // avoid nothingness
            let isDefaultIcon = iconStyle == .calendar // not important, can be replaced
            let skipIcon = isDefaultIcon && hasBirthdays // replace default icon with birthday

            if showIcon && !skipIcon {
                icons.append(StatusItemIconFactory.icon(size: iconSize, style: iconStyle, dateProvider: dateProvider))
            }

            return icons
        }
        .share(replay: 1)

        self.image = Observable.combineLatest(
            icons,
            settings.showStatusItemBackground
        )
        .debounce(.nanoseconds(1), scheduler: scheduler)
        .map { icons, showBackground in
            let radius: CGFloat = 3
            let border: CGFloat = 0.5
            let padding: NSPoint = .init(x: border, y: border)
            let spacing: CGFloat = 4
            let iconsWidth = icons.map(\.size.width).reduce(0) { $0 + $1 + spacing } - spacing
            let height = max(icons.map(\.size.height).reduce(0, max), 15)
            var size = CGSize(width: iconsWidth, height: height)

            let iconsImage = NSImage(size: size, flipped: false) {
                var offsetX: CGFloat = 0
                for icon in icons {
                    icon.draw(at: .init(x: offsetX, y: 0), from: $0, operation: .sourceOver, fraction: 1)
                    offsetX += icon.size.width + spacing
                }
                return true
            }

            iconsImage.isTemplate = true

            guard showBackground else {
                return iconsImage
            }

            size.width += 2 * padding.x
            size.height += 2 * padding.y

            let image = NSImage(size: size, flipped: false) {
                NSBezierPath(roundedRect: $0, xRadius: radius, yRadius: radius).addClip()
                NSColor.red.drawSwatch(in: $0)
                iconsImage.draw(at: padding, from: $0, operation: .destinationOut, fraction: 1)
                return true
            }

            image.isTemplate = true

            return image
        }
    }
}

private func dateFormatContainsTime(_ format: String) -> Bool {
    ["H", "h", "m", "s"].contains(where: { format.contains($0) })
}
