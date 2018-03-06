Supplier.create!([
  {id: 1, name: "Amazon"}
])
Account.create!([
  {id: 1, supplier_id: 1, account_number: "314159"}
])
AccountHistory.create!([
  {id: 1, account_id: 1, credit_rating: 700}
])
Physician.create!([
  {id: 1, name: "Hippocrates"}
])
Patient.create!([
  {id: 1, name: "Plato"}
])
Appointment.create!([
  {id: 1, physician_id: 1, patient_id: 1, appointment_date: "2018-01-03 04:50:44"}
])
Author.create!([
  {id: 1, name: "David Foster Wallace"}
])
Book.create!([
  {id: 1, author_id: 1, published_at: "2018-01-03 04:51:38"}
])
Assembly.create!([
  {id: 1, name: "car"},
  {id: 2, name: "truck"}
])
Part.create!([
  {id: 1, part_number: "12345"},
  {id: 2, part_number: "67890"}
])
Object.const_get('Assembly::HABTM_Parts').create!([
  {part_id: 1, assembly_id: 1},
  {part_id: 2, assembly_id: 1},
  {part_id: 1, assembly_id: 2}
])
