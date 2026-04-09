import CoreData
import Foundation

@objc(Product)
final class Product: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var barcodeValue: String
    @NSManaged var barcodeTypeRaw: String
    @NSManaged var customName: String
    @NSManaged var brand: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var lastScannedAt: Date
    @NSManaged var priceEntries: Set<PriceEntry>

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        barcodeValue: String,
        barcodeType: BarcodeType,
        customName: String = "",
        brand: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastScannedAt: Date = .now
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Product", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.barcodeValue = barcodeValue
        self.barcodeTypeRaw = barcodeType.rawValue
        self.customName = customName
        self.brand = brand
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastScannedAt = lastScannedAt
        self.priceEntries = []
    }

    var barcodeType: BarcodeType {
        get { BarcodeType(rawValue: barcodeTypeRaw) ?? .unknown }
        set { barcodeTypeRaw = newValue.rawValue }
    }

    var displayName: String {
        customName.nilIfBlank ?? barcodeValue
    }
}

extension Product {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Product> {
        NSFetchRequest<Product>(entityName: "Product")
    }
}
