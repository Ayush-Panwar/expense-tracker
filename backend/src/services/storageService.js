const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

const uploadImage = async (file) => {
    const fileName = `${Date.now()}_${file.originalname}`;

    const { data, error } = await supabase.storage
        .from('receipts')
        .upload(fileName, file.buffer, {
            contentType: file.mimetype,
        });

    if (error) {
        throw new Error('Image upload failed');
    }

    const { data: urlData } = supabase.storage
        .from('receipts')
        .getPublicUrl(fileName);

    return urlData.publicUrl;
};

module.exports = { uploadImage };