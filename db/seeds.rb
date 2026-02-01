# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Clear existing data
puts "🧹 Clearing existing data..."
[ AuditEvent, Delivery, MessageLog, Request, Document, Policy, Client, ConversationSession, User, Agency, Account ].each(&:destroy_all)

# Create Account
puts "🏦 Creating account..."
account = Account.create!(
  name: "Reliable Insurance Group",
  subscription_status: "active"
)

# Create Agencies (2 locations/brands under the same account)
puts "🏢 Creating agencies..."
agency_downtown = Agency.create!(
  name: "Reliable Insurance - Downtown",
  phone_sms: "+15551234567",  # Placeholder E.164 number for testing
  account: account,
  active: true
)

agency_westside = Agency.create!(
  name: "Reliable Insurance - Westside",
  phone_sms: "+15551234568",
  account: account,
  active: true
)

# Create owner User
puts "👤 Creating owner user..."
user = User.create!(
  account: account,
  first_name: "John",
  last_name: "Owner",
  email: "john@reliableinsurance.example",
  password: "password123",
  role: "owner"
)

# Create Clients (distributed across both agencies)
puts "📱 Creating clients..."
# Downtown agency clients
client1 = Client.create!(
  agency: agency_downtown,
  first_name: "Alice",
  last_name: "Johnson",
  phone_mobile: "+15559876543"
)

client2 = Client.create!(
  agency: agency_downtown,
  first_name: "Bob",
  last_name: "Smith",
  phone_mobile: "+15559876544"
)

# Westside agency clients
client3 = Client.create!(
  agency: agency_westside,
  first_name: "Carol",
  last_name: "Williams",
  phone_mobile: "+15559876545"
)

client4 = Client.create!(
  agency: agency_westside,
  first_name: "David",
  last_name: "Brown",
  phone_mobile: "+15559876546"
)

# Create Policies for each client
puts "📋 Creating policies..."
policies = []

# Alice's policies
policies << Policy.create!(
  client: client1,
  label: "2018 Honda Accord",
  policy_type: "auto",
  expires_on: 6.months.from_now
)

policies << Policy.create!(
  client: client1,
  label: "2020 Toyota Camry",
  policy_type: "auto",
  expires_on: 8.months.from_now
)

policies << Policy.create!(
  client: client1,
  label: "2015 Ford F-150",
  policy_type: "auto",
  expires_on: 3.months.from_now
)

# Bob's policies
policies << Policy.create!(
  client: client2,
  label: "2019 Chevrolet Silverado",
  policy_type: "auto",
  expires_on: 4.months.from_now
)

policies << Policy.create!(
  client: client2,
  label: "2021 Tesla Model 3",
  policy_type: "auto",
  expires_on: 10.months.from_now
)

policies << Policy.create!(
  client: client2,
  label: "2017 Subaru Outback",
  policy_type: "auto",
  expires_on: 2.months.from_now
)

# Carol's policies (Westside)
policies << Policy.create!(
  client: client3,
  label: "2022 BMW X5",
  policy_type: "auto",
  expires_on: 9.months.from_now
)

policies << Policy.create!(
  client: client3,
  label: "123 Oak Street",
  policy_type: "homeowners",
  expires_on: 11.months.from_now
)

# David's policies (Westside)
policies << Policy.create!(
  client: client4,
  label: "2020 Mercedes C300",
  policy_type: "auto",
  expires_on: 5.months.from_now
)

policies << Policy.create!(
  client: client4,
  label: "456 Maple Avenue",
  policy_type: "homeowners",
  expires_on: 7.months.from_now
)

# Create Documents with attached files for each policy
puts "📄 Creating documents with insurance cards..."
fixture_path = Rails.root.join("test/fixtures/files/sample_insurance_card.pdf")

policies.each do |policy|
  doc = Document.create!(
    policy: policy,
    kind: "auto_id_card"
  )
  doc.file.attach(
    io: File.open(fixture_path),
    filename: "insurance_card_#{policy.label.parameterize}.pdf",
    content_type: "application/pdf"
  )
end

puts "\n✅ Seed data created successfully!"
puts "\n📊 Summary:"
puts "  - Accounts: #{Account.count}"
puts "  - Agencies: #{Agency.count}"
puts "  - Users: #{User.count}"
puts "  - Clients: #{Client.count}"
puts "  - Policies: #{Policy.count}"
puts "  - Documents: #{Document.count}"
puts "  - Documents with files: #{Document.joins(:file_attachment).count}"

puts "\n🏛️  Account → Agencies → Users Hierarchy:"
puts "  └── #{account.name} (#{account.subscription_status})"
account.agencies.each do |ag|
  puts "      └── #{ag.name} (active: #{ag.active})"
  puts "          └── Clients: #{ag.clients.count}, Policies: #{ag.clients.joins(:policies).count}"
end
account.users.each do |u|
  puts "      └── #{u.first_name} #{u.last_name} (#{u.role})"
end

puts "\n📱 Test Phone Numbers:"
puts "  - Downtown Agency SMS: #{agency_downtown.phone_sms}"
puts "  - Westside Agency SMS: #{agency_westside.phone_sms}"
puts "  - Alice Johnson: #{client1.phone_mobile}"
puts "  - Bob Smith: #{client2.phone_mobile}"
puts "  - Carol Williams: #{client3.phone_mobile}"
puts "  - David Brown: #{client4.phone_mobile}"
puts "\n👤 Admin Login:"
puts "  - Email: #{user.email}"
puts "  - Password: password123"
