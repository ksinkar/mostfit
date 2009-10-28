class Hash
  def / (other)
    rhash = {}
    keys.each do |k|
      if has_key?(k) and other.has_key?(k)
        rhash[k] = self[k]/other[k]
      else
        rhash[k] = nil
      end
    end
    rhash
  end

  def - (other)
    rhash = {}
    keys.each do |k|
      if has_key?(k) and other.has_key?(k)
        rhash[k] = self[k] - other[k]
      else
        rhash[k] = nil
      end
    end
    rhash
  end
end

module Reporting
  module BranchReports
    # we must convert each SQL struct into a hash of {:branch_id =< :value}, so that we are always looking at 
    # the correct branch, and we have to refactor the divison, multiplication, etc. of these arrays
    def query_as_hash(sql)
      #puts sql
      repository.adapter.query(sql).map {|x| [x[0],x[1]]}.to_hash
    end

    def client_count(date = Date.today)
      query_as_hash(%Q{
          SELECT b.id, COUNT(cl.id) as count
          FROM clients cl, centers c, branches b
          WHERE cl.center_id = c.id AND c.branch_id = b.id and cl.date_joined < '#{date}'
          GROUP BY b.id})            
    end

    def loan_count(date = Date.today)
      query_as_hash(%Q{
          SELECT b.id,COUNT(*) 
          FROM loans l, clients cl, centers c, branches b
          WHERE l.client_id = cl.id AND cl.center_id = c.id AND c.branch_id = b.id and l.created_at <='#{date}'
          GROUP BY b.id})            
    end

    def active_client_count(date = Date.today)
      query_as_hash(%Q{
            SELECT branch_id, count(*) 
            FROM (
                  SELECT loan_id, max(date), status, branch_id 
                  FROM loan_history 
                  WHERE date < '#{date}'
                  GROUP BY loan_id) AS dt 
            WHERE status <= 3
            GROUP BY branch_id})
    end

    def dormant_client_count(date = Date.today)
      client_count(date) - active_client_count(date)
    end

    def client_count_by_loan_cycle(loan_cycle, date=Date.today)
      # this simply counts the number of loans for a given client without taking into account the status of those loans.
      query_as_hash(%Q{
            SELECT branch_id, COUNT(client_id) 
            FROM (
               SELECT client_id, count(*) AS num_loans, branch_id, center_id 
               FROM (
                  SELECT loan_id, client_id, center_id, branch_id,date, status,concat(client_id,'_',status) 
                  FROM loan_history 
                  WHERE concat(loan_id,'_',date) IN (
                      SELECT concat(loan_id,'_', max(date)) 
                      FROM loan_history 
                      WHERE date < '#{date}' 
                      GROUP BY loan_id)  
                  GROUP BY CONCAT(client_id,'_',status)) AS dt1 
               GROUP BY client_id
               HAVING num_loans = #{loan_cycle}) 
               AS dt2 
               GROUP BY branch_id})
    end

    def clients_added_between_such_and_such_date_count(start_date, end_date)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      query_as_hash(%Q{
        SELECT b.id, COUNT(c.id) 
        FROM clients c, centers ce, branches b
        WHERE date_joined BETWEEN '#{start_date}' AND '#{end_date}'
        AND c.center_id = ce.id AND ce.branch_id = b.id
        GROUP BY b.id})
    end

    def clients_deleted_between_such_and_such_date_count(start_date, end_date)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      query_as_hash(%Q{
        SELECT b.id, COUNT(c.id) 
        FROM clients c, centers ce, branches b
        WHERE deleted_at BETWEEN '#{start_date}' AND '#{end_date}'
              AND c.center_id = ce.id AND ce.branch_id = b.id
        GROUP BY b.id})
    end

    def loans_repaid_between_such_and_such_date(start_date, end_date, what)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      return unless what.downcase == "sum" or what.downcase == "count"
        query_as_hash(%Q{
         SELECT lh.branch_id,#{what}(l.amount)
         FROM loans l, loan_history lh
         WHERE l.id = lh.loan_id 
               AND  lh.status = #{STATUSES.index(:repaid) + 1}  AND lh.date BETWEEN '#{start_date}' AND '#{end_date}'
         GROUP BY lh.branch_id})
    end

    def loans_disbursed_between_such_and_such_date(start_date, end_date, what)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      return unless what.downcase == "sum" or what.downcase == "count"
        query_as_hash(%Q{
         SELECT lh.branch_id, #{what}(l.amount)
         FROM loans l, loan_history lh
         WHERE l.id = lh.loan_id 
               AND  lh.status = #{STATUSES.index(:disbursed) + 1} AND  l.disbursal_date BETWEEN '#{start_date}' AND '#{end_date}'
         GROUP BY lh.branch_id})
    end

    def principal_due_between_such_and_such_date(start_date, end_date)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      query_as_hash(%Q{
           SELECT branch_id, SUM(principal_due) 
           FROM loan_history lh
           WHERE date BETWEEN '#{start_date}' AND '#{end_date}'
           GROUP BY branch_id })
    end

    def principal_received_between_such_and_such_date(start_date, end_date)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      query_as_hash(%Q{
           SELECT branch_id, SUM(principal_paid) 
           FROM loan_history lh
           WHERE date BETWEEN '#{start_date}' AND '#{end_date}'
           GROUP BY branch_id })
    end

    def interest_due_between_such_and_such_date(start_date, end_date)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      query_as_hash(%Q{
           SELECT branch_id, SUM(interest_due) 
           FROM loan_history lh
           WHERE date BETWEEN '#{start_date}' AND '#{end_date}'
           GROUP BY branch_id })
    end

    def interest_received_between_such_and_such_date(start_date, end_date)
      start_date = Date.parse(start_date) unless start_date.is_a? Date
      end_date = Date.parse(end_date) unless end_date.is_a? Date
      query_as_hash(%Q{
           SELECT branch_id, SUM(interest_paid) 
           FROM loan_history lh
           WHERE date BETWEEN '#{start_date}' AND '#{end_date}'
           GROUP BY branch_id })
    end

    def principal_outstanding(date = Date.today)
      date = Date.parse(date) unless date.is_a? Date
      query_as_hash(%Q{
          SELECT branch_id, SUM(actual_outstanding_principal)
          FROM loan_history 
          WHERE concat(loan_id,'_',date) IN (
             SELECT concat(loan_id,'_',max(date)) as _id
             FROM loan_history
             WHERE date < '#{date}'
             GROUP BY loan_id)
          GROUP by branch_id})

    end

    def scheduled_principal_outstanding(date = Date.today)
      date = Date.parse(date) unless date.is_a? Date
      query_as_hash(%Q{
          SELECT branch_id, SUM(scheduled_outstanding_principal)
          FROM loan_history 
          WHERE concat(loan_id,'_',date) IN (
             SELECT concat(loan_id,'_',max(date)) as _id
             FROM loan_history
             WHERE date < '#{date}'
             GROUP BY loan_id)
          GROUP by branch_id})
    end

    def total_outstanding(date = Date.today)
      date = Date.parse(date) unless date.is_a? Date
      query_as_hash(%Q{
          SELECT branch_id, SUM(actual_outstanding_total)
          FROM loan_history 
          WHERE concat(loan_id,'_',date) IN (
             SELECT concat(loan_id,'_',max(date)) as _id
             FROM loan_history
             WHERE date < '#{date}'
             GROUP BY loan_id)
          GROUP by branch_id})
    end

    def scheduled_total_outstanding(date = Date.today)
      date = Date.parse(date) unless date.is_a? Date
      query_as_hash(%Q{
          SELECT branch_id, SUM(scheduled_outstanding_total)
          FROM loan_history 
          WHERE concat(loan_id,'_',date) IN (
             SELECT concat(loan_id,'_',max(date)) as _id
             FROM loan_history
             WHERE date < '#{date}'
             GROUP BY loan_id)
          GROUP by branch_id})
    end


    def center_managers(start_date, end_date)
      query_as_hash("select branch_id, count(distinct(manager_staff_id)) from centers group by branch_id;")
    end

    def avg_outstanding_balance
      query_as_hash("select branch_id, avg(actual_outstanding_principal) from loan_history where current = true group by branch_id;")
    end

    def overdue_by(min, max)
      repository.adapter.query("SELECT branch_id, SUM(amount_in_default) FROM loan_history WHERE current = true AND days_overdue BETWEEN #{min} and #{max} GROUP BY branch_id").map {|x| [x[0],x[1].to_f]}.to_hash
    end

    def method_missing(name, *params)
      if /avg_(\w+)_per_(\w+)/.match(name.to_s)
        num = params ? send($1, *params[0]) : send($1)
        den = (params and params[1]) ? send($2, *params[1]) : send($2)
      else
        raise "No such method #{name}"
      end
    end


  end
end
