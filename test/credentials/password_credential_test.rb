require File.expand_path('../../test_helper', __FILE__)

class PasswordCredentialTest < ActiveSupport::TestCase
  def setup
    @credential = Credentials::Password.new
    @credential.password = 'awesome'
    @credential.password_confirmation = 'awesome'
    @credential.user = users(:bill)
    @_password_expires = Credentials::Password.expires_after
  end

  def teardown
    Credentials::Password.expires_after = @_password_expires
  end

  test 'setup' do
    assert @credential.valid?
  end

  test 'key not required' do
    @credential.key = nil
    assert @credential.valid?
  end

  test 'user presence' do
    @credential.user = nil
    assert !@credential.valid?
  end

  test 'user uniqueness' do
    @credential.user = users(:john)
    assert !@credential.valid?
  end

  test 'password confirmation' do
    @credential.password_confirmation = 'not awesome'
    assert !@credential.valid?
  end

  test 'password required' do
    @credential.password = @credential.password_confirmation = nil
    assert !@credential.valid?
  end

  test 'check_password' do
    assert_equal true, @credential.check_password('awesome')
    assert_equal false, @credential.check_password('not awesome'),
                 'Bogus password'
    assert_equal false, @credential.check_password('password'),
                 "Another user's password"
  end

  test 'expired?' do
    @credential.updated_at = Time.now
    assert_equal false, @credential.expired?
    @credential.updated_at = Time.now - 2.years
    assert_equal true, @credential.expired?
    Credentials::Password.expires_after = nil
    assert_equal false, @credential.expired?
  end

  test 'authenticate' do
    @credential.updated_at = Time.now
    assert_equal users(:bill), @credential.authenticate('awesome')
    assert_equal :invalid, @credential.authenticate('not awesome')
    Credentials::Password.expires_after = 1.month
    @credential.updated_at = Time.now - 1.year
    assert_equal :expired, @credential.authenticate('awesome')
  end

  test 'authenticate calls User#auth_bounce_reason' do
    user = @credential.user
    user.expects(:auth_bounce_reason).at_least_once.returns(:reason)
    @credential.updated_at = Time.now
    assert_equal :reason, @credential.authenticate('awesome')
    assert_equal :invalid, @credential.authenticate('not awesome')
  end

  test 'authenticate_email' do
    assert_equal users(:john),
        Credentials::Password.authenticate_email('john@gmail.com', 'password')
    assert_equal :invalid,
        Credentials::Password.authenticate_email('john@gmail.com', 'pa55w0rd'),
        "Jane's password on John's account"
    assert_equal users(:jane),
        Credentials::Password.authenticate_email('jane@gmail.com', 'pa55w0rd')
    assert_equal :invalid,
        Credentials::Password.authenticate_email('jane@gmail.com', 'password'),
        "John's password on Jane's account"
    assert_equal :invalid,
        Credentials::Password.authenticate_email('john@gmail.com', 'awesome'),
        'Bogus password'
    assert_equal :invalid,
        Credentials::Password.authenticate_email('bill@gmail.com', 'pa55w0rd'),
        'Password authentication on account without password credential'
    assert_equal :invalid,
        Credentials::Password.authenticate_email('none@gmail.com', 'pa55w0rd'),
        'Bogus e-mail'
  end
end
