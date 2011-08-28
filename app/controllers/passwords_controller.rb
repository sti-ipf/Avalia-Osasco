class PasswordsController < ApplicationController
  def generate_all_letters
    @passwords = Password.all
    respond_to do |format|
      format.html {render :layout => false}
      format.pdf {render :layout => false, :pdf => "password_letters"}
    end
  end

  def generate_all_passwords
    pg = IPF::PasswordGenerator.new
    pg.generate
    redirect_to admin_passwords_path, :notice => "Senhas geradas com sucesso."
  end
end

