/// An object which is uniquely identified by its object identifier.
public class PointerHasher: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }

  public static func == (lhs: PointerHasher, rhs: PointerHasher) -> Bool {
    lhs === rhs
  }
}
