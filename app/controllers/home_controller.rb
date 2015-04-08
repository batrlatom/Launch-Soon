# Controller for main page
class HomeController < ApplicationController

  def index
    @ref = params['ref']
  end


  def interested
    require 'mailchimp'
    require 'digest'

    return redirect_to root_url if params['email'].blank?

    @ref           = params['ref']
    email          = params['email']
    @referral_code = Digest::MD5.hexdigest(email)

    begin
      mailchimp = Mailchimp::API.new(MAILCHIMP_API_KEY)
    rescue => e
      flash.now[:alert] = 'There was a problem connecting to MailChimp'
      return render :index
    end

logger.info("mailchimp connected")

    begin
      user_info = mailchimp.lists.member_info(MAILCHIMP_LIST_ID, ['email' => "#{email}"])
    rescue => e
      flash.now[:alert] = 'There was a problem getting info on this email address from MailChimp'
      return render :index
    end

logger.info("mail info success")

    if user_info['errors'].any?
      user_info['errors'].each do |error|
        if error['code'] == 232 # The user is not in the list
          unless @ref.blank? # Increment RCOUNT for referrer if referral code is present
            begin
              list_members     = mailchimp.lists.members("#{MAILCHIMP_LIST_ID}")
              referring_member = list_members['data'].detect { |member| member['merges']['RCODE'] == "#{@ref}" }
logger.info("memberfound : #{email}")
              new_count        = referring_member['merges']['RCOUNT']	
add_count = new_count.to_i + 1
	

logger.info("membercount:  : #{add_count}")
              mailchimp.lists.update_member("#{MAILCHIMP_LIST_ID}", {'euid' => "#{referring_member['id']}"}, 'RCOUNT' => "#{add_count}")
logger.info("member updated")
            rescue => e
              flash.now[:alert] = 'There was a problem updating the referral at MailChimp'
logger.info("membercount error")
              return render :index
            end
          end

          begin
            mailchimp.lists.subscribe("#{MAILCHIMP_LIST_ID}", 
                                      {'email' => "#{email}"}, 
					
                                      {'RCODE' => "#{@referral_code}", 'RCOUNT' => '0'}, "double_optin" => "false")
          rescue => e
            flash.now[:alert] = 'There was a problem subscribing you to the list on MailChimp'
            return render :index
          end
logger.info("mail added")
        end
      end
    else # The user is in the list
      @rcount = user_info['data'][0]['merges']['RCOUNT']
      @rcode  = user_info['data'][0]['merges']['RCODE']
logger.info("user found")
      return render :stats
    end
  end
end
