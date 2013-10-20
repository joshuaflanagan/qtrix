harness :heavy_load do
  target_rate 100000000

  queue :audits do
    job :audit_job do
      volume 40
      runtime_min 1
      runtime_max 2
      error_rate 0.01
    end

    job :email_job do
      volume 30
      runtime_min 2
      runtime_max 3
      error_rate 0.1
    end

    job :import_job do
      volume 15
      runtime_min 20
      runtime_max 25
      error_rate 0.2
    end

    job :export_job do
      volume 15
      runtime_min 20
      runtime_max 25
      error_rate 0.23
    end
  end
end
