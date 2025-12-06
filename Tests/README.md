# Test Suite Documentation

## Обзор

Этот документ описывает структуру тестового набора для VPNBarApp, включая unit тесты, integration тесты, моки и утилиты.

## Структура тестов

```
Tests/
├── VPNBarAppTests/              # Unit тесты
│   ├── Models/                  # Тесты моделей
│   ├── ViewModels/              # Тесты view models
│   ├── Managers/                # Тесты менеджеров
│   ├── Controllers/             # Тесты контроллеров
│   ├── Utilities/               # Тесты утилит
│   ├── Mocks/                   # Моки для зависимостей
│   └── Helpers/                 # Тестовые утилиты
└── VPNBarAppIntegrationTests/    # Integration тесты
```

## Запуск тестов

### Все тесты

```bash
# Используя Swift Package Manager
swift test

# Используя Makefile
make test

# Используя скрипт
./Scripts/run_tests.sh
```

### Только unit тесты

```bash
swift test --filter VPNBarAppTests

# Или через Makefile
make test-unit
```

### Только integration тесты

```bash
swift test --filter VPNBarAppIntegrationTests

# Или через Makefile
make test-integration
```

### С покрытием кода

```bash
swift test --enable-code-coverage

# Или через Makefile
make coverage
```

## Написание тестов

### Соглашение об именовании

Используйте формат: `test_[methodName]_[scenario]_[expectedResult]`

Примеры:
- `test_login_withValidCredentials_returnsSuccess()`
- `test_fetchData_whenNetworkFails_throwsError()`
- `test_emailValidator_withEmptyString_returnsFalse()`

### Шаблон теста

```swift
import XCTest
@testable import VPNBarApp

final class MyClassTests: XCTestCase {
    var sut: MyClass!
    var mockDependency: MockDependency!
    
    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = MyClass(dependency: mockDependency)
    }
    
    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }
    
    func test_methodName_scenario_expectedResult() {
        // Given (Arrange)
        let input = "test"
        let expected = "expected"
        
        // When (Act)
        let result = sut.methodName(input)
        
        // Then (Assert)
        XCTAssertEqual(result, expected)
    }
}
```

### Паттерн Given-When-Then

Все тесты должны следовать структуре:
1. **Given (Arrange)** - настройка начального состояния
2. **When (Act)** - выполнение тестируемого действия
3. **Then (Assert)** - проверка результата

### Тестирование async/await

```swift
func test_asyncMethod_scenario_result() async throws {
    // Given
    let expected = "result"
    
    // When
    let result = try await sut.asyncMethod()
    
    // Then
    XCTAssertEqual(result, expected)
}
```

### Тестирование Combine publishers

```swift
func test_publisher_emitsValue() {
    // Given
    let expectation = expectation(description: "Publisher emits")
    var cancellables = Set<AnyCancellable>()
    var receivedValue: String?
    
    // When
    sut.publisher
        .sink { value in
            receivedValue = value
            expectation.fulfill()
        }
        .store(in: &cancellables)
    
    sut.triggerPublisher()
    
    // Then
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedValue, "expected")
}
```

## Моки

### Доступные моки

- `MockVPNManager` - мок для VPNManagerProtocol
- `MockSettingsManager` - мок для SettingsManagerProtocol
- `MockNotificationManager` - мок для NotificationManager
- `MockHotkeyManager` - мок для HotkeyManager

### Использование моков

```swift
let mockVPNManager = MockVPNManager()
mockVPNManager.connections = [VPNConnectionFactory.createConnected()]

let sut = MyClass(vpnManager: mockVPNManager)

// После выполнения теста
XCTAssertTrue(mockVPNManager.connectCalled)
XCTAssertEqual(mockVPNManager.connectConnectionID, "test-id")
```

## Тестовые утилиты

### VPNConnectionFactory

Фабрика для создания тестовых VPN подключений:

```swift
// Создать подключение
let connection = VPNConnectionFactory.create(
    id: "test-id",
    name: "Test VPN",
    status: .connected
)

// Создать подключенное подключение
let connected = VPNConnectionFactory.createConnected()

// Создать несколько подключений
let connections = VPNConnectionFactory.createMultiple(count: 5)
```

### TestHelpers

Вспомогательные функции для тестов:

```swift
// Ожидание асинхронной операции
await TestHelpers.waitForAsync(timeout: 1.0)

// Ожидание условия
await TestHelpers.waitForCondition {
    sut.isReady
}
```

## Покрытие кода

### Требования к покрытию

- **Models**: 90%+
- **ViewModels**: 85%+
- **Managers**: 80%+
- **Controllers**: 75%+
- **Utilities**: 90%+
- **Общее покрытие**: 75%+

### Просмотр покрытия

1. Запустите тесты с покрытием:
   ```bash
   swift test --enable-code-coverage
   ```

2. Откройте проект в Xcode:
   ```bash
   open Package.swift
   ```

3. В Xcode: Product → Show Code Coverage

## CI/CD интеграция

### GitHub Actions

Тесты автоматически запускаются при:
- Push в ветки `main` и `develop`
- Создании Pull Request

Workflow файл: `.github/workflows/tests.yml`

### Локальный запуск CI

```bash
# Используя act (если установлен)
act -j test
```

## Troubleshooting

### Тесты не компилируются

1. Убедитесь, что все зависимости установлены:
   ```bash
   swift package resolve
   ```

2. Очистите кэш:
   ```bash
   swift package clean
   ```

3. Пересоберите:
   ```bash
   swift build
   ```

### Flaky тесты

Если тесты иногда падают:

1. Проверьте использование таймеров - используйте моки
2. Проверьте асинхронные операции - увеличьте timeout
3. Проверьте состояние между тестами - убедитесь в правильном tearDown

### Медленные тесты

Если тесты выполняются медленно:

1. Проверьте integration тесты - они могут быть медленнее
2. Используйте параллельное выполнение (по умолчанию включено)
3. Оптимизируйте тяжелые операции в тестах

## Best Practices

1. **Изоляция**: Каждый тест должен быть независимым
2. **Чистота**: Используйте setUp и tearDown для очистки
3. **Именование**: Используйте описательные имена тестов
4. **Моки**: Мокируйте внешние зависимости
5. **Покрытие**: Стремитесь к высокому покрытию, но не в ущерб качеству
6. **Скорость**: Unit тесты должны выполняться быстро (< 0.1s каждый)
7. **Читаемость**: Тесты должны быть понятны без комментариев

## Дополнительные ресурсы

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Best Practices](https://www.swift.org/documentation/)
- [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)

