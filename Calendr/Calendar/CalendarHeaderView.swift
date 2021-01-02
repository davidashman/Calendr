//
//  CalendarHeaderView.swift
//  Calendr
//
//  Created by Paker on 26/12/20.
//

import RxSwift
import RxCocoa

class CalendarHeaderView: NSView {
    private let stackView = NSStackView(.horizontal)
    private let label = Label()
    private let prevBtn = NSButton()
    private let resetBtn = NSButton()
    private let nextBtn = NSButton()

    private let disposeBag = DisposeBag()

    init(viewModel: CalendarHeaderViewModel) {

        super.init(frame: .zero)

        disposeBag.insert(
            prevBtn.rx.tap.bind(to: viewModel.prevBtnObserver),
            resetBtn.rx.tap.bind(to: viewModel.resetBtnObserver),
            nextBtn.rx.tap.bind(to: viewModel.nextBtnObserver)
        )

        configureLayout()

        setUpBindings(with: viewModel)
    }

    private func configureLayout() {
        label.font = .systemFont(ofSize: 14, weight: .semibold)

        prevBtn.image = NSImage(named: NSImage.goBackTemplateName)
        resetBtn.image = NSImage(named: NSImage.refreshTemplateName)
        nextBtn.image = NSImage(named: NSImage.goForwardTemplateName)

        [prevBtn, resetBtn, nextBtn].forEach {
            $0.size(equalTo: 22)
            $0.bezelStyle = .regularSquare
            $0.isBordered = false
        }

        let btnStackView = NSStackView(.horizontal)

        btnStackView.spacing = 0
        btnStackView.addArrangedSubviews(prevBtn, resetBtn, nextBtn)

        stackView.addArrangedSubviews(label, btnStackView)

        addSubview(stackView)

        stackView.edges(to: self)
    }

    private func setUpBindings(with viewModel: CalendarHeaderViewModel) {
        viewModel
            .titleObservable
            .bind(to: label.rx.string)
            .disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
