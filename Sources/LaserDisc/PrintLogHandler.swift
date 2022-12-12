import Embassy

final class PrintLogHandler: LogHandler {
    var formatter: LogFormatter?

    func emit(record: LogRecord) {
        guard let formatter = formatter else {
            return
        }
        let formattedRecord = formatter.format(record: record)
        print("\(formattedRecord)")
    }
}
