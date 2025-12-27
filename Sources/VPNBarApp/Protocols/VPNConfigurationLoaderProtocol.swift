import Foundation

/// Протокол для загрузки VPN-конфигураций из системы.
@MainActor
protocol VPNConfigurationLoaderProtocol {
    /// Загружает доступные VPN-конфигурации.
    /// - Parameter completion: Обработчик результата загрузки.
    func loadConfigurations(completion: @escaping (Result<[VPNConnection], VPNError>) -> Void)
}


