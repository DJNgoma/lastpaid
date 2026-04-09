import CoreData
import Foundation

@objc(PriceEntry)
final class PriceEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged private var amountStorage: String
    @NSManaged var currencyCode: String
    @NSManaged var storeName: String?
    @NSManaged var quantityText: String?
    @NSManaged var notes: String?
    @NSManaged var purchasedAt: Date
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var product: Product?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        amount: Decimal,
        currencyCode: String,
        storeName: String? = nil,
        quantityText: String? = nil,
        notes: String? = nil,
        purchasedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        product: Product? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "PriceEntry", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.amountStorage = Self.serialize(amount)
        self.currencyCode = currencyCode
        self.storeName = storeName
        self.quantityText = quantityText
        self.notes = notes
        self.purchasedAt = purchasedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.product = product
    }

    var amount: Decimal {
        get {
            Decimal(string: amountStorage, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
        }
        set {
            amountStorage = Self.serialize(newValue)
        }
    }

    private static func serialize(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}

extension PriceEntry {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PriceEntry> {
        NSFetchRequest<PriceEntry>(entityName: "PriceEntry")
    }
}
