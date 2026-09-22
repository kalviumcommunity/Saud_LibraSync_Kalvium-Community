# LibraSync Security & Firestore Rules Documentation

## Overview

LibraSync utilizes role-based access control (RBAC) enforced both at the application service layer (Flutter) and at the database layer ([`firestore.rules`](./firestore.rules)).

---

## 1. Role Hierarchy & Assumptions

| Role | Description | Privilege Level |
| :--- | :--- | :--- |
| **Guest / Unauthenticated** | Anonymous or unauthenticated visitors | Read-only access to public catalogues (books, branches, book copies). |
| **Member** | Authenticated library patron | Can manage their own profile (cannot escalate role), borrow books, return their own loans, and stream their own loan history. |
| **Staff / Admin** | Authorized library staff or administrators | Full administrative access over catalog items, physical copies, branch definitions, user management, and circulation records. |

### Role Resolution Strategy
1. **Custom Token Claims**: Evaluates `request.auth.token.role == 'staff'` / `request.auth.token.role == 'admin'` / `request.auth.token.isStaff == true`.
2. **Firestore User Profile**: Falls back to reading `/users/{uid}.data.role` matching `'staff'` or `'admin'`.
3. **Safe Fallback**: Any missing, empty, unknown, or malformed role string defaults to `member` (or `guest` for unauthenticated sessions).

---

## 2. Collection Access Boundaries Matrix

| Collection | Path | Read Access | Create Access | Update Access | Delete Access |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Users** | `/users/{userId}` | Authenticated users | Owner (`role == 'member'`) or Staff | Staff, or Owner modifying non-role fields | Staff only |
| **Books** | `/books/{bookId}` | Public (`true`) | Staff (with field validation) | Staff (all fields), or Authenticated members (atomic copy count decrement/increment only) | Staff only |
| **Loans** | `/loans/{loanId}` | Owner (`memberId == uid`) or Staff | Authenticated member (`status == 'active'`) for self, or Staff | Staff, or Owner returning own active loan (`status == 'returned'`) | Staff only |
| **Branches** | `/branches/{branchId}` | Public (`true`) | Staff only | Staff only | Staff only |
| **Book Copies** | `/bookCopies/{copyId}` | Public (`true`) | Staff only | Staff only | Staff only |

---

## 3. Defense-in-Depth Enforcement

1. **Self-Elevation Prevention**: Members cannot write `role: 'staff'` or `role: 'admin'` to their `/users/{userId}` document. Profile creation enforces `request.resource.data.role == 'member'` unless performed by staff. Profile updates reject changes where `request.resource.data.role != resource.data.role`.
2. **Copy Invariant Invariants**: In `/books/{bookId}`, creation and updates validate that `totalCopies >= 1`, `0 <= availableCopies <= totalCopies`, and `isAvailable == (availableCopies > 0)`.
3. **Loan Record Ownership**: In `/loans/{loanId}`, members cannot modify another member's loan record or transition records to states other than `'returned'` with a valid `returnDate`.

---

## 4. Testing & Emulator Boundary Notes

- **Unit & Widget Test Coverage**: Flutter unit and widget tests verify application-level guards, role resolution, ownership verification, and UI control gating across [`test/role_based_access_test.dart`](./test/role_based_access_test.dart) and related suites.
- **Firebase Emulator Requirement**: Direct automated verification of Firestore security rules expressions without application mocks requires the Node.js `@firebase/rules-unit-testing` framework running against the local Firebase Firestore Emulator.
- **Emulator Setup Status**: The local Firebase Emulator is not configured within this pure Flutter repository. Security rules are verified through static analysis, AST consistency, and Flutter unit test mock validation.

---

## 5. Security Considerations for Production

1. **Token Claims Synchronization**: For optimum performance and minimal Firestore reads in `isStaff()`, assign custom claims (`{ role: 'staff' }`) via Cloud Functions / Firebase Admin SDK on staff promotion.
2. **Transactions & Rate Limiting**: Ensure borrow/return transactions continue to use Firestore atomic transactions to prevent race conditions during copy decrementing.
