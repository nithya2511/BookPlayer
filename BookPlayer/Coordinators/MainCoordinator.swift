//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import DeviceKit
import MediaPlayer
import RevenueCat
import UIKit

class MainCoordinator: Coordinator {
  let tabBarController: AppTabBarController

  let playerManager: PlayerManager
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let accountService: AccountServiceProtocol
  let watchConnectivityService: PhoneWatchConnectivityService

  init(
    navigationController: UINavigationController,
    libraryService: LibraryServiceProtocol,
    accountService: AccountServiceProtocol
  ) {
    self.libraryService = libraryService
    self.accountService = accountService
    let playbackService = PlaybackService(libraryService: libraryService)
    self.playbackService = playbackService

    self.playerManager = PlayerManager(
      libraryService: libraryService,
      playbackService: self.playbackService,
      speedService: SpeedService(libraryService: libraryService)
    )

    let watchService = PhoneWatchConnectivityService(
      libraryService: libraryService,
      playbackService: playbackService,
      playerManager: playerManager
    )
    self.watchConnectivityService = watchService

    ThemeManager.shared.libraryService = libraryService

    let viewModel = MiniPlayerViewModel(playerManager: self.playerManager)
    self.tabBarController = AppTabBarController(miniPlayerViewModel: viewModel)
    tabBarController.modalPresentationStyle = .fullScreen
    tabBarController.modalTransitionStyle = .crossDissolve

    super.init(navigationController: navigationController, flowType: .modal)
    viewModel.coordinator = self

    accountService.loginIfUserExists()
    accountService.setDelegate(self)
  }

  override func start() {
    self.presentingViewController = tabBarController

    if let currentTheme = try? self.libraryService.getLibraryCurrentTheme() {
      ThemeManager.shared.currentTheme = SimpleTheme(with: currentTheme)
    }

    let libraryCoordinator = LibraryListCoordinator(
      navigationController: AppNavigationController.instantiate(from: .Main),
      playerManager: self.playerManager,
      importManager: ImportManager(libraryService: self.libraryService),
      libraryService: self.libraryService,
      playbackService: self.playbackService
    )
    libraryCoordinator.tabBarController = tabBarController
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()

    let profileCoordinator = ProfileCoordinator(
      libraryService: self.libraryService,
      accountService: self.accountService,
      navigationController: AppNavigationController.instantiate(from: .Main)
    )
    profileCoordinator.tabBarController = tabBarController
    profileCoordinator.parentCoordinator = self
    self.childCoordinators.append(profileCoordinator)
    profileCoordinator.start()

    let settingsCoordinator = SettingsCoordinator(
      libraryService: self.libraryService,
      accountService: self.accountService,
      navigationController: AppNavigationController.instantiate(from: .Settings)
    )
    settingsCoordinator.tabBarController = tabBarController
    settingsCoordinator.parentCoordinator = self
    self.childCoordinators.append(settingsCoordinator)
    settingsCoordinator.start()

    self.watchConnectivityService.startSession()

    self.navigationController.present(tabBarController, animated: false)
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      presentingViewController: self.presentingViewController
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }

  func showMiniPlayer(_ flag: Bool) {
    guard flag else {
      self.tabBarController.animateView(self.tabBarController.miniPlayer, show: flag)
      return
    }

    if self.playerManager.hasLoadedBook() {
      self.tabBarController.animateView(self.tabBarController.miniPlayer, show: flag)
    }
  }

  func hasPlayerShown() -> Bool {
    return self.childCoordinators.contains(where: { $0 is PlayerCoordinator })
  }

  func getLibraryCoordinator() -> LibraryListCoordinator? {
    return self.childCoordinators.first as? LibraryListCoordinator
  }

  func getTopController() -> UIViewController? {
    return getPresentingController(coordinator: self)
  }

  func getPresentingController(coordinator: Coordinator) -> UIViewController? {
    guard let lastCoordinator = coordinator.childCoordinators.last else {
      return coordinator.presentingViewController?.getTopViewController()
      ?? coordinator.navigationController
    }

    return getPresentingController(coordinator: lastCoordinator)
  }
}

extension MainCoordinator: PurchasesDelegate {
  public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    self.accountService.updateAccount(from: customerInfo)
  }
}
